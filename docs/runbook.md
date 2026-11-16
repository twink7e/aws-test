# 部署、验收与清理手册

以下命令以仓库根目录为起点，目标区域固定为 `ap-northeast-1`。执行 `apply` 会创建计费资源。首次上云前，先阅读根目录 [README.md](../README.md) 中的目标与输入清单，以及 [架构说明](architecture.md)。

成本决策：本次使用单 AZ 小规格 RDS、平时 1 个小规格 Fargate 应用任务，不建设 RDS Multi-AZ 或跨 AZ 热备。ALB 的两个 AZ 子网属于服务接入要求，并不代表数据库具备多 AZ 容灾。演示结束及时按本文第 5 节清理资源。

## 0. 准备账号和本机工具

- AWS CLI 使用本机仓库根目录的 `AKSK.env`。先从根目录运行 `source ./AKSK.env`，再运行 `export AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION=ap-northeast-1`，最后运行 `aws sts get-caller-identity`，确认是测评账号。`AKSK.env` 已被 Git 忽略，不要把其内容复制到文档或提交仓库。
- Terraform 版本满足各 stack 的 `versions.tf`；Docker Buildx 可构建 `linux/arm64`；有权限在 GitHub 仓库设置 Actions variables。
- 独立 GitHub 测试账号下的 [fafafafa868888/poper-test](https://github.com/fafafafa868888/poper-test) 仓库已创建，当前显示 Public；首次推送前检查忽略文件，推送后验证匿名访问。使用 `main` 分支和 GitHub 托管 runner，不需要新建常驻 CI 服务器。
- 告警别名已定为 `zhangsan`：`minghe.yin+zhangsan@poper.co`、`te.qi+zhangsan@poper.co`。创建订阅后，两位收件人都要点击确认邮件；否则 SNS 不会投递。

建议同时设置 `AWS_REGION=ap-northeast-1`，并在每次 `apply` 前重新确认账号身份。仓库里的 `*.example` 文件只含示例值，实际的 `terraform.tfvars`、`backend.hcl` 均被 `.gitignore` 排除。

## 1. 引导 Terraform state bucket

进入 `infra/terraform/bootstrap/`，复制 `terraform.tfvars.example` 为 `terraform.tfvars`，按需修改项目名前缀。然后运行：

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output -raw state_bucket_name
```

记录输出的 bucket 名称。`bootstrap` 使用本地 `terraform.tfstate`，这个文件含资源元数据，必须安全保存，不要提交到 Git。S3 bucket 开启版本化、加密、TLS 限制和阻止公开访问；后两个 stack 的 S3 backend 使用同一个 bucket 的不同 object key，并用 S3 lockfile 加锁。

## 2. 部署 foundation

进入 `infra/terraform/foundation/`。复制 `backend.hcl.example` 为 `backend.hcl`，将 bucket 改成上一步的真实名称；复制 `terraform.tfvars.example` 为 `terraform.tfvars`，填写相同的项目名、state bucket 名、告警邮箱和可选证书。本机的实际变量文件已经写入 `zhangsan` 对应的两个收件地址。

```sh
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out=foundation.tfplan
terraform apply foundation.tfplan
terraform output
```

此 stack 创建 VPC、两个公有子网、两个私有数据库子网、ALB、ECS cluster、RDS PostgreSQL、ECR 三个仓库、S3 备份桶、受账号边界约束的 IAM 运行角色、AppConfig、SNS、CloudWatch 日志组及 ALB 日志投递。SNS 邮件订阅会向填写的地址发送确认邮件，部署完成后应立即确认。RDS 主密码由 RDS 托管到 Secrets Manager；Laravel `APP_KEY` 也存放于 Secrets Manager。Terraform state 仍需限制访问，因为生成密钥的值会进入 state。

账号要求自建角色名以 `itv-` 开头并附加 `InterviewCandidate-Boundary`。此账号没有 Step Functions 或 SQS 权限；备份改为 Scheduler、Lambda、ECS 和 EventBridge。`foundation` 的输出将给 workload stack 和 GitHub Actions 使用；不要把敏感输出粘贴到公开 issue。

## 3. 设置 GitHub Actions 并首次发布

在 GitHub 仓库 Settings → Secrets and variables → Actions → Variables 配置：

| Variable | 值 |
| --- | --- |
| `TF_STATE_BUCKET` | bootstrap 输出的 Terraform state bucket 名。 |
| `AWS_REGION` | `ap-northeast-1`。 |
| `SNS_TOPIC_ARN` | foundation 输出的通知 topic ARN。 |
| `TF_PROJECT_NAME` | 可选；项目资源名前缀，默认 `poper-test`，须与 foundation 的 `project_name` 一致。 |

同一页面的 Secrets 配置 `AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY`，对应本地 `AKSK.env` 中的 `AK`、`SK`。不要把密钥放进 Actions Variables、工作流 YAML 或仓库文件。该测评使用现有受限 IAM 用户，测试结束删除这两个 Secrets，并轮换或停用这组 AK/SK。

推送到 `main`，或者在 Actions 页面手动启动 release workflow。工作流先构建并本地测试 `linux/arm64` 的 PHP、Nginx 和备份镜像，随后读取 AWS Secrets、验证 workload Terraform，推送镜像到 ECR，以镜像 digest 作为 Terraform 输入并执行 `apply`。工作流发送发布成功或失败通知。如果首次推送时尚未配置 Secrets/Variables，工作流会清楚地跳过部署；配置完成后在 Actions 页面重新启动即可。若 AWS 认证本身失效，SNS 通知 job 也无法发送，须查看 Actions 失败状态。

本地手工部署 workload 时，进入 `infra/terraform/workload/`，从 `backend.hcl.example` 复制 `backend.hcl`，设置与 foundation 相同的 bucket，key 改为 workload 的 state key；从 `terraform.tfvars.example` 复制 `terraform.tfvars`，填入 foundation state bucket 及三个真实 ECR digest URI，然后执行 `terraform init -backend-config=backend.hcl && terraform plan && terraform apply`。正式发布以 CI/CD 为准，避免本机与 Actions 同时修改同一个 state。

## 4. 逐项验收

### 首页与健康检查

打开 foundation 输出的 ALB DNS 地址。`/healthz` 应返回 200；首页应显示在 workload 中设置的非敏感 `DEMO_MESSAGE` 和 AppConfig 配置。若没有提供 ACM 证书，使用 ALB 的 HTTP 地址；提供证书后，80 端口会重定向至 443。

### 日志和看板

带一个自定义 `X-Amzn-Trace-Id` 请求头访问首页，随后在 CloudWatch Logs 查看 Nginx JSON 记录中的同名字段、HTTP 状态码和请求路径；查看 app、PHP-FPM、AppConfig Agent、ALB 与 backup 日志组。CloudWatch Dashboard 应显示 ECS desired/running task、CPU、内存、ALB HTTP 状态和 500 比例。所有日志组都有保留期，默认测试保留期可在变量中调整。

### 定时任务数

Application Auto Scaling 在东京时间 17:00 将 ECS 服务的最小/最大容量都设为 2，在 18:00 设回 1。可在 AWS 控制台查看 Scheduled actions 和 ECS service desired/running count。真实任务停止时间受 ECS 部署、连接排空与停止宽限影响，通常不是整点瞬时完成。手工测试时可以临时把两个 cron 改到最近时间，验收后恢复并重新 `apply`。

### 数据库全量备份和恢复

从仓库根目录手动调用 workload 输出的备份控制器 Lambda：

```sh
aws lambda invoke \
  --function-name "$(terraform -chdir=infra/terraform/workload output -raw backup_controller_lambda_name)" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"launch"}' \
  /tmp/poper-backup-launch.json
cat /tmp/poper-backup-launch.json
```

确认调用没有 `FunctionError`，响应含 `started: true` 和 ECS task ARN，然后等待备份任务 `STOPPED` 且退出码为 0；在 S3 查找新生成的 `.dump` 对象，检查大小大于零。备份程序使用 `pg_dump -Fc`，它是 PostgreSQL 的逻辑全量 dump。下载副本后可先执行 `pg_restore --list backup.dump` 检查目录；完整恢复演练要在**隔离的临时数据库**中运行 `pg_restore` 并比对表和示例数据，不要覆盖正在运行的 RDS 数据库。Scheduler 每天东京时间 02:00 调用控制器；控制器检查 ECS `RunTask` 响应中的 `Failures` 和任务列表，ECS `STOPPED` 事件再检查退出码。失败会发 SNS 告警，Scheduler、EventBridge、Lambda 的调用失败也有 CloudWatch 告警。

### 告警触发

先确认 SNS 两个订阅均为 `Confirmed`。测试环境可暂时启用 workload 变量 `enable_demo_failure_routes`，用应用的受控测试路由产生一次 JSON `ERROR` 和多次 HTTP 500；再访问正常首页制造对照请求。CloudWatch metric filter 与 Alarm 一般按分钟级窗口评估；HTTP 500 比例告警需要在同一窗口内超过 10%。演示结束立即关闭测试路由并重新发布。备份失败告警可以在 ECS 控制台手工启动备份任务，并用容器 override 把 `DB_HOST` 临时改成无效主机；`STOPPED` 事件应进入控制器并通知 SNS。测试后恢复参数，不要改动生产数据。记录 CloudWatch Alarm 状态、SNS 邮件、ECS 任务和 S3 对象截图作为交付证据。

### AppConfig 发布

后续配置发布前，把 foundation 的 `appconfig_use_gradual_deployment` 设为 `true`，再更新 `appconfig_initial_content` JSON，执行 `terraform plan` 和 `terraform apply`，等待 AppConfig deployment 完成；首页应在 Agent 轮询后显示新值。AppConfig 的部署监控使用应用 `ERROR` CloudWatch Alarm 作为回滚信号；EventBridge 扩展把完成与回滚事件发送至 SNS。这里的配置是动态读取的；若需要修改 ECS 进程环境变量，必须重新部署任务定义，不能指望 AppConfig 自动改写已启动进程的环境。

## 5. 清理

先 `terraform destroy` workload，后 destroy foundation，最后才处理 bootstrap state bucket。删除 workload 前保存需要的截图、日志与数据库备份。foundation 的备份 S3 bucket 默认 `force_destroy = false`：先备份或明确删除其中对象，再销毁；若要自动清空，应显式设置 `force_destroy_backup_bucket = true` 并核对计划。bootstrap state bucket 有 `prevent_destroy` 防误删保护，必须先安全归档需要的 state，再移除保护并清理该 bucket。RDS 默认跳过最终快照，销毁会永久删除数据库；操作前核对备份。销毁后复查 AWS Resource Groups/Cost Explorer 中该项目标签对应的资源，尤其是 ALB、RDS、ECR 镜像、CloudWatch Logs 和 S3 对象。

## 6. 当前无法离线验证的项目

仓库可在本地执行格式检查、Terraform 静态验证、Docker 构建和应用测试。已用提供的 AWS 凭证确认账号并应用 `bootstrap`、`foundation`；`workload` 的实际 `apply`、RDS 连接、ALB 日志投递、SNS 邮件确认、17:00/18:00 调度与备份恢复仍须云端验收。GitHub 登录态显示仓库 Public，但匿名访问账号主页和仓库返回 404；需复核账号公开可见性。GitHub Actions 运行、Console URL 与告警截图仍需补齐。
