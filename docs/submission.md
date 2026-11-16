# POPER 课题交付索引

更新日期：2026-11-16。本页按原题的提交清单组织入口，供打包发送或整理为公开在线文档时使用；**当前尚未完成对外提交**。AWS 控制台链接是东京区域的服务入口，需登录有权限的测评账号，再按右列资源名查找；它们不是无需登录的公开资源链接。不要在交付包中附上 `AKSK.env`、Terraform state、真实 `terraform.tfvars` / `backend.hcl`、数据库密码或题目原件。

## 仓库与运行地址

| 项目 | 链接 | 当前状态 |
| --- | --- | --- |
| 全部代码 | [twink7e/aws-test](https://github.com/twink7e/aws-test) | `main` 已推送；匿名仓库和 README 均返回 HTTP 200。提交历史中常见 AWS key、GitHub PAT、私钥模式和敏感路径扫描未命中。 |
| Laravel 首页 | [ALB HTTP 地址](http://poper-test-alb-565988149.ap-northeast-1.elb.amazonaws.com/) | 首页与 `/healthz` 已实测 HTTP 200；测试环境使用 HTTP。 |
| CI/CD 工作流 | [release.yml](https://github.com/twink7e/aws-test/actions/workflows/release.yml)、[首次 run 43813162697](https://github.com/twink7e/aws-test/actions/runs/43813162697)、[原生 ARM run 43815555640](https://github.com/twink7e/aws-test/actions/runs/43815555640) | 两次 push run 均成功；测试、三张镜像推送 ECR、Terraform apply、ECS 稳定性检查和 SNS 发布结果步骤通过。第二次部署 `poper-test-web:5`。 |
| 发布失败通知演练 | [受控失败 run 43824754336](https://github.com/twink7e/aws-test/actions/runs/43824754336) | `workflow_dispatch` 按预期整体失败：preflight 成功，release 在构建前故意失败，Docker/ECR/Terraform 步骤均跳过；`notify` job 成功以 `RELEASE_RESULT=failure` 发布 SNS 消息，返回 MessageId `3b9da49d-3953-556f-accf-c7e98c503560`。邮件送达未验证。 |

## AWS 平台功能入口

项目区域为 `ap-northeast-1`（东京），资源名前缀为 `poper-test`。下面列出控制台入口及可用于检索的已知资源名；动态生成的 bucket 名可从 Terraform 输出读取。

| 功能 | 东京区域 Console 入口 | 资源线索 / 验证重点 |
| --- | --- | --- |
| 网络与安全组 | [VPC](https://console.aws.amazon.com/vpc/home?region=ap-northeast-1) | `poper-test-vpc`；公有 ALB 子网与私有数据库子网。 |
| 负载均衡与目标健康 | [EC2 / Load Balancers](https://console.aws.amazon.com/ec2/home?region=ap-northeast-1) | `poper-test-alb`；查看 listener、target group 与健康目标。 |
| PHP 应用与定时扩缩容 | [ECS `poper-test-web` service](https://ap-northeast-1.console.aws.amazon.com/ecs/v2/clusters/poper-test-cluster/services/poper-test-web/events?region=ap-northeast-1) | `poper-test-cluster`、`poper-test-web`；正式 17:00 JST 扩容后实查 desired/running 2/2、两个 ALB 目标健康。查看 task、service、Auto Scaling scheduled actions；18:00 缩容待观察。 |
| 镜像版本 | [ECR](https://console.aws.amazon.com/ecr/repositories?region=ap-northeast-1) | `poper-test/app`、`poper-test/web`、`poper-test/backup`；核对镜像 digest。 |
| PostgreSQL | [RDS](https://console.aws.amazon.com/rds/home?region=ap-northeast-1) | `poper-test-postgres`；单 AZ、私有访问、最小规格。 |
| 数据库 dump 与 Terraform state | [S3](https://console.aws.amazon.com/s3/home?region=ap-northeast-1) | 备份 bucket 名见 `foundation` 输出 `backup_bucket_name`；state bucket 名见 `bootstrap` 输出 `state_bucket_name`。 |
| 动态配置与发布 | [AWS AppConfig](https://console.aws.amazon.com/systems-manager/appconfig/?region=ap-northeast-1) | 应用 `poper-test`；受控 `ERROR` 告警触发渐进部署 `#4` 自动回滚，稳定版本恢复部署 `#5` 完成。ALB 首页显示稳定文案且不含演练临时文案，`foundation` 详细计划无差异。详见[回滚证据](evidence/appconfig-rollback-2026-11-16.md)。 |
| 每日备份调度 | [EventBridge Scheduler](https://console.aws.amazon.com/scheduler/home?region=ap-northeast-1) | group `poper-test-backup`、schedule `poper-test-daily-backup`；当前为 `cron(0 2 * * ? *)`、`Asia/Tokyo`。 |
| 备份控制器 | [Lambda](https://console.aws.amazon.com/lambda/home?region=ap-northeast-1) | `poper-test-backup-controller`；查看调用与失败分类。 |
| 访问、应用、备份日志 | [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1) | 在 Log groups 中查 `/poper-test/app`、`/poper-test/web`、`/poper-test/backup` 及 ALB 日志组；[Trace ID 关联实测](evidence/trace-correlation-2026-11-16.md)核对了同一请求的 ALB、Nginx 与 Laravel JSON 日志。 |
| ECS / ALB 指标与看板 | [CloudWatch `poper-test-operations` Dashboard](https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards/dashboard/poper-test-operations) | 已在 Chrome 看到 ECS running/desired、CPU/内存、ALB 目标 HTTP 状态分类和 ALB 生成错误四个图表及真实数据。 |
| 应用、ALB、备份告警 | [ALB 精确 HTTP 500 比例告警](https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#alarmsV2:alarm/poper-test-alb-exact-500-ratio)、[CloudWatch Alarms 入口](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1) | 查 `poper-test-application-error`、`poper-test-alb-exact-500-ratio`、`poper-test-backup-failed` 及 action history。 |
| 告警与发布通知 | [SNS](https://console.aws.amazon.com/sns/v3/home?region=ap-northeast-1) | topic `poper-test-alerts`；新别名的两条邮件订阅均为 `PendingConfirmation`。旧别名的一条未确认订阅暂时残留，等待 AWS 自动过期；无收件箱送达证据。 |
| 运行时密钥 | [Secrets Manager](https://console.aws.amazon.com/secretsmanager/home?region=ap-northeast-1) | RDS 托管密码与 Laravel `APP_KEY`；只核对资源存在和权限，不展示值。 |

## 文档、架构图与告警演示

| 原题交付项 | 仓库入口 | 当前状态 |
| --- | --- | --- |
| 架构图（图片） | [架构图](architecture.png)、[架构说明](architecture.md) | 已生成。 |
| 核心操作流程 | [部署、验收、清理手册](runbook.md) | 包含 Terraform 部署、镜像发布、备份恢复及清理步骤。 |
| 告警触发方法 | [运行手册：告警触发](runbook.md#告警触发) | 说明应用 `ERROR`、ALB 500 比例和备份失败的受控触发方法；测试路由已关闭。 |
| 触发后的实际记录 | [告警历史时间线](evidence/cloudwatch-alarm-history.md)、[部署与验收记录](deployment-evidence.md)、[逐项验收清单](acceptance.md) | 三种告警均实测进入 `ALARM` 并恢复 `OK`，CloudWatch action history 显示 SNS topic action 执行成功；八个项目告警目前均为 `OK`。 |
| 告警触发后的截图 | [应用 `ERROR` History](evidence/cloudwatch-application-error-history.png)、[ALB 精确 HTTP 500 比例 History](evidence/cloudwatch-alb-exact-500-ratio-history.png)、[备份失败 History](evidence/cloudwatch-backup-failed-history.png) | 三张截图均已保存，包含告警状态变化及 SNS topic action；完整 UTC 时间线见[告警历史记录](evidence/cloudwatch-alarm-history.md)。截图不证明邮件送达。 |
| AppConfig 自动回滚 | [受控回滚时间线](evidence/appconfig-rollback-2026-11-16.md) | 渐进部署 `#4` 因 CloudWatch 应用错误告警自动进入 `ROLLED_BACK`，稳定版本部署 `#5` 后续完成，AppConfig 环境恢复 `ReadyForDeployment`。回滚及完成规则各匹配、调用一次；SNS 在完成分钟发布 1 条消息，与事件相符但无法逐条归因，邮件送达未验证。 |
| 正式 17:00 定时扩容 | [定时扩缩容时间线](evidence/scheduled-scaling-2026-11-16.md) | 16:58:42 JST 为 ECS 1/1；计划动作于 17:00 后触发，17:02:52 ECS 达到 2/2 且两个 ALB 目标健康。正式 18:00 缩容尚待观察。 |

## 提交前仍需完成

1. 两位新别名收件人确认 SNS 邮件订阅后，重新触发通知并保存邮件送达证据；目前已验证 CloudWatch 告警和 Actions 发布结果均向 SNS topic 发出动作，没有收件箱送达记录。
2. 三种告警 History 截图已齐；若补充日志、看板等其他 AWS Console 截图，检查画面没有密钥、密码或私有配置。
3. 按原题要求将本页、文档、架构图和代码整理为可发送的交付包，或发布为可匿名打开的在线文档。正式东京时间 17:00 扩容已实测，18:00 缩容和 02:00 每日备份仍待观察；临时调度动作已验证扩缩机制，AppConfig 自动回滚已实测。
