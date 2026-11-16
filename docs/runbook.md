# 部署、验收与清理手册

以下命令以仓库根目录为起点，目标区域固定为 `ap-northeast-1`。执行 `apply` 会创建计费资源。复现或变更前，先阅读根目录 [README.md](../README.md) 中的目标与输入清单，以及 [架构说明](architecture.md)。当前三个 Terraform stack 均已应用；实测结果见 [部署证据](deployment-evidence.md)。

成本决策：本次使用单 AZ 小规格 RDS、平时 1 个小规格 Fargate 应用任务，不建设 RDS Multi-AZ 或跨 AZ 热备。ALB 的两个 AZ 子网属于服务接入要求，并不代表数据库具备多 AZ 容灾。演示结束及时按本文第 5 节清理资源。

## 0. 准备账号和本机工具

- AWS CLI 使用本机仓库根目录的 `AKSK.env`。先从根目录运行 `source ./AKSK.env`，再运行 `export AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION=ap-northeast-1`，最后运行 `aws sts get-caller-identity`，确认是测评账号。`AKSK.env` 已被 Git 忽略，不要把其内容复制到文档或提交仓库。
- Terraform 版本满足各 stack 的 `versions.tf`；Docker Buildx 可构建 `linux/arm64`；有权限在 GitHub 仓库设置 Actions variables。
- [twink7e/aws-test](https://github.com/twink7e/aws-test) 匿名仓库和 README 均返回 HTTP 200；两个 Actions Secrets 和四个 Variables 已配置。[首次 run 43813162697](https://github.com/twink7e/aws-test/actions/runs/43813162697) 与 [原生 ARM run 43815555640](https://github.com/twink7e/aws-test/actions/runs/43815555640) 均成功。GitHub Actions 使用托管 runner，不需要新建常驻 CI 服务器。
- 告警别名已定为 `shuo.xiao`：`minghe.yin+shuo.xiao@poper.co`、`te.qi+shuo.xiao@poper.co`。更换订阅后，两位收件人均须点击新的 SNS 确认邮件，否则新邮箱不会收到通知。

2026-11-16 更换订阅的 Terraform `apply` 为 2 项新增、2 项销毁，复查计划无差异。SNS 列表暂时有三条 `PendingConfirmation`：两条是新的 `shuo.xiao` 地址，另一条是旧 `zhangsan` 地址的未确认残留。后者已不在 Terraform state 中；[AWS 说明](https://docs.aws.amazon.com/sns/latest/dg/sns-delete-subscription-topic.html)未确认订阅不能手工删除，通常在 48 小时后自动过期。旧别名已确认的订阅已删除，新地址确认前没有有效邮件收件人。

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

进入 `infra/terraform/foundation/`。复制 `backend.hcl.example` 为 `backend.hcl`，将 bucket 改成上一步的真实名称；复制 `terraform.tfvars.example` 为 `terraform.tfvars`，填写相同的项目名、state bucket 名、告警邮箱和可选证书。本机的实际变量文件已经写入 `shuo.xiao` 对应的两个收件地址。

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

## 3. GitHub Actions 与首次发布

在 GitHub 仓库 Settings → Secrets and variables → Actions → Variables 配置：

| Variable | 值 |
| --- | --- |
| `TF_STATE_BUCKET` | bootstrap 输出的 Terraform state bucket 名。 |
| `AWS_REGION` | `ap-northeast-1`。 |
| `SNS_TOPIC_ARN` | foundation 输出的通知 topic ARN。 |
| `TF_PROJECT_NAME` | 可选；项目资源名前缀，默认 `poper-test`，须与 foundation 的 `project_name` 一致。 |

上述四个 Variables 和两个 Secrets `AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY` 已在新仓库配置，后两者对应本地 `AKSK.env` 中的 `AK`、`SK`。不要把密钥放进 Actions Variables、工作流 YAML 或仓库文件。该测评使用现有受限 IAM 用户，测试结束删除这两个 Secrets，并轮换或停用这组 AK/SK。

`main` 上首次 [release run 43813162697](https://github.com/twink7e/aws-test/actions/runs/43813162697) 和原生 ARM runner 的 [run 43815555640](https://github.com/twink7e/aws-test/actions/runs/43815555640) 均已成功。第二次运行由 release commit `0d91b5d` 触发；PHP-FPM 镜像构建耗时 1 分 27 秒，首次 QEMU 运行耗时 13 分 23 秒。工作流先构建并本地测试 `linux/arm64` 的 PHP、Nginx 和备份镜像，随后读取 AWS Secrets、验证 workload Terraform，推送镜像到 ECR，以镜像 digest 作为 Terraform 输入并执行 `apply`；第二次部署 `poper-test-web:5`，ECS 稳定性检查通过。两次成功运行的 `notify` job 均通过；失败通知分支尚未实测。若 AWS 认证本身失效，SNS 通知 job 也可能无法认证，须同时查看 Actions 失败状态。

验证发布失败通知时，在 GitHub Actions 的 **Build and deploy → Run workflow** 中选 `main`，勾选 `simulate_failure` 后手动运行。该开关仅对 `workflow_dispatch` 生效，预期 `release` job 在构建镜像前故意失败，`notify` job 向 `SNS_TOPIC_ARN` 发布主题为 `POPER deployment failure` 的消息并附运行链接；检查 Actions 结果及已确认订阅的收件箱，保存证据。执行前须确保 preflight 的 Secrets、Variables 完整且 AWS 认证有效。此演练尚未执行，不应把预期结果写成已验证结果。

已通过手动路径完成首次发布：三张 `linux/arm64` 镜像本地构建和测试后推送 ECR，取得各自 digest URI，并通过 `workload` 的 `terraform apply` 首次创建 23 项资源。复现时进入 `infra/terraform/workload/`，从 `backend.hcl.example` 复制 `backend.hcl`，设置与 foundation 相同的 bucket，key 改为 workload 的 state key；从 `terraform.tfvars.example` 复制 `terraform.tfvars`，填入 foundation state bucket 及三个真实 ECR digest URI，再执行 `terraform init -backend-config=backend.hcl && terraform plan && terraform apply`。后续自动发布已验证；本机与 Actions 不应同时修改同一个 state。每次手工计划应使用当前已发布的镜像 digest，旧的本地 `terraform.tfvars` 可能提出回退镜像的变更。

## 4. 逐项验收

### 首页与健康检查

打开 foundation 输出的 ALB DNS 地址。首次发布后，首页和 `/healthz` 均实测返回 HTTP 200；首页显示 `DEMO_MESSAGE` 的 `Hello from POPER test` 和 AppConfig 的 `Hello from AppConfig`。若没有提供 ACM 证书，使用 ALB 的 HTTP 地址；提供证书后，80 端口会重定向至 443。

### 日志和看板

CloudWatch Logs 已收到 Nginx JSON、Laravel/PHP-FPM、ALB JSON、备份及 Lambda 控制器日志；自定义 `X-Amzn-Trace-Id` 已在 Nginx 与 Laravel 日志中查到。复现时带一个自定义追踪头访问首页，再逐项核对日志内容。CloudWatch Dashboard 已有底层真实指标：ECS/ContainerInsights `RunningTaskCount` 数据点为 1.0，AWS/ECS `CPUUtilization` 有数据点；看板还应显示 ECS desired/running task、CPU、内存、ALB HTTP 状态和 500 比例，截图待整理。所有日志组都有保留期，默认测试保留期可在变量中调整。

### 定时任务数

Application Auto Scaling 的默认配置是在东京时间 17:00 将 ECS 服务的最小/最大容量都设为 2，在 18:00 设回 1。2026-11-16 通过 `TF_VAR_ecs_scale_out_schedule_expression` 和 `TF_VAR_ecs_scale_in_schedule_expression` 临时设置 `at(2026-11-16T13:10:00)` / `at(2026-11-16T13:13:00)`，时区为 `Asia/Tokyo`；Terraform `apply` 为 0 新增、2 修改、0 销毁。13:10 前 desired/running 1/1、容量上下限 1/1；13:10:49 desired 2/running 1/pending 1、上下限 2/2；13:11:32 desired/running 2/2，两个 ALB 目标健康；13:13:22 desired/running 1/1、上下限 1/1。测试后重新 `apply` 恢复两项默认 cron，AWS 查询确认表达式为 `cron(0 17 * * ? *)` / `cron(0 18 * * ? *)`、时区均为 `Asia/Tokyo`；当前上下限与 ECS desired/running 均为 1/1，最终 workload 详细计划无差异。正式 17:00/18:00 窗口尚未观察。复现时可临时覆盖两个表达式，测试后取消覆盖并重新 `terraform apply`，再查询 AWS 中两项 scheduled action 的表达式与时区，并执行 `terraform plan -detailed-exitcode`。真实任务启动、连接排空和停止宽限会影响期望数与运行数达到目标的时间。

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

首次手工调用已成功启动并完成备份任务，S3 dump 为 16,664 字节；该 dump 在隔离的 PostgreSQL 17 实例恢复出 9 张表和 3 条 migration 记录。临时 Scheduler 于 2026-11-16 东京时间 12:52 自动启动备份任务，退出码为 0，S3 也收到 16,664 字节 dump；随后通过 Terraform 恢复正式表达式 `cron(0 2 * * ? *)`、时区 `Asia/Tokyo`。每天 02:00 的真实运行仍待观察。复现手工调用时确认没有 `FunctionError`，响应含 `started: true` 和 ECS task ARN，然后等待备份任务 `STOPPED` 且退出码为 0；在 S3 查找新生成的 `.dump` 对象，检查大小大于零。备份程序使用 `pg_dump -Fc`，它是 PostgreSQL 的逻辑全量 dump。完整恢复演练须在**隔离的临时数据库**中运行 `pg_restore`，不要覆盖正在运行的 RDS 数据库。控制器检查 ECS `RunTask` 响应中的 `Failures` 和任务列表，ECS `STOPPED` 事件再检查退出码。失败会发 SNS 告警，Scheduler、EventBridge、Lambda 的调用失败也有 CloudWatch 告警。

### 告警触发

受控测试已经使应用 `ERROR` 告警在 2 条事件后进入 `ALARM`，ALB HTTP 500 精确比例告警在 89.655% 时进入 `ALARM`；测试故障路由已关闭，两个路径均返回 404，ALB 告警恢复 `OK`，应用告警于 2026-11-16 03:53 UTC 恢复 `OK`。受控备份失败任务退出码为 1，Lambda 判定 `false`，`BackupFailed` 指标为 1，备份失败告警进入 `ALARM`，并于 2026-11-16 11:58:27 UTC+08 恢复 `OK`。应用错误与备份失败告警的周期均由 300 秒改为 60 秒；分别通过 foundation 和 workload Terraform 各修改 1 项、无新增或销毁。三个告警的 action history 均显示 SNS topic action 成功执行，详细时间见[告警历史记录](evidence/cloudwatch-alarm-history.md)，但新别名的两条订阅均为 `PendingConfirmation`，目前未保存收件箱送达证据；待两位新别名收件人确认后须重新触发并保存邮件证据。复现时可暂时启用 workload 变量 `enable_demo_failure_routes`，用受控测试路由产生 JSON `ERROR` 和多次 HTTP 500，再访问正常首页制造对照请求。CloudWatch metric filter 与 Alarm 一般按分钟级窗口评估；HTTP 500 比例告警需要在同一窗口内超过 10%。演示结束立即关闭测试路由并重新发布。备份失败告警可以在 ECS 控制台手工启动备份任务，并用容器 override 把 `DB_HOST` 临时改成无效主机；`STOPPED` 事件应进入控制器并通知 SNS。测试后恢复参数，不要改动生产数据。记录 CloudWatch Alarm 状态、SNS 邮件、ECS 任务和 S3 对象截图作为交付证据。

### AppConfig 发布

已将 AppConfig 临时内容 `Live update verified` 发布并在首页看到变化，期间 ECS 任务定义未改动；之后通过 Terraform 恢复默认内容，首页再次显示 `Hello from AppConfig`。自动回滚与 SNS 通知仍待验证。复现配置发布时，更新 foundation 的 `appconfig_initial_content` JSON，执行 `terraform plan` 和 `terraform apply`，等待 AppConfig deployment 完成并在 Agent 轮询后刷新首页。测试自动回滚前，将 `appconfig_use_gradual_deployment` 设为 `true`；AppConfig 的部署监控使用应用 `ERROR` CloudWatch Alarm 作为回滚信号，EventBridge 扩展把完成与回滚事件发送至 SNS。这里的配置是动态读取的；若需要修改 ECS 进程环境变量，必须重新部署任务定义，不能指望 AppConfig 自动改写已启动进程的环境。

## 5. 清理

先 `terraform destroy` workload，后 destroy foundation，最后才处理 bootstrap state bucket。删除 workload 前保存需要的截图、日志与数据库备份。foundation 的备份 S3 bucket 默认 `force_destroy = false`：先备份或明确删除其中对象，再销毁；若要自动清空，应显式设置 `force_destroy_backup_bucket = true` 并核对计划。bootstrap state bucket 有 `prevent_destroy` 防误删保护，必须先安全归档需要的 state，再移除保护并清理该 bucket。RDS 默认跳过最终快照，销毁会永久删除数据库；操作前核对备份。销毁后复查 AWS Resource Groups/Cost Explorer 中该项目标签对应的资源，尤其是 ALB、RDS、ECR 镜像、CloudWatch Logs 和 S3 对象。

## 6. 当前进度与剩余验收

已在东京区域应用 `bootstrap` 6 项、`foundation` 88 项、`workload` 首次 23 项；手工镜像构建/ECR 推送/Terraform 发布、ALB 首页与健康检查、手工备份及隔离恢复、临时 Scheduler 备份、AppConfig 动态更新与恢复均已通过。临时 scheduled action 已实测将 ECS 从 1 个任务扩至 2 个健康目标，再缩回 1 个；默认 17:00/18:00 cron 和东京时区已通过 AWS 查询核实，正式窗口尚未观察。应用 `ERROR`、ALB HTTP 500 比例和备份失败告警均已实际进入 `ALARM` 并恢复 `OK`；测试故障路由已关闭。手工验收后的 `foundation` 和 `workload` Terraform 详细计划均为退出码 0、无差异。每天 02:00 正式自动备份、AppConfig 自动回滚及 SNS 邮件送达仍待验收；三种告警的 History 截图已入库，新别名的两条 SNS 邮件订阅均为 `PendingConfirmation`。[新 GitHub 仓库](https://github.com/twink7e/aws-test) 匿名仓库和 README 均为 HTTP 200；两次 Actions run 均成功，第二次部署 `poper-test-web:5`，AWS 复查 ECS desired/running 1/1、pending 0、单 deployment、rollout `COMPLETED`，ALB 首页与 `/healthz` 均为 HTTP 200。详见 [部署证据](deployment-evidence.md)。
