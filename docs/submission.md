# POPER 课题交付索引

更新日期：2026-11-16。本页按原题的提交清单组织入口，供打包发送或整理为公开在线文档时使用；**当前尚未完成对外提交**。AWS 控制台链接是东京区域的服务入口，需登录有权限的测评账号，再按右列资源名查找；它们不是无需登录的公开资源链接。不要在交付包中附上 `AKSK.env`、Terraform state、真实 `terraform.tfvars` / `backend.hcl`、数据库密码或题目原件。

## 仓库与运行地址

| 项目 | 链接 | 当前状态 |
| --- | --- | --- |
| 全部代码 | [fafafafa868888/poper-test](https://github.com/fafafafa868888/poper-test) | `main` 已推送；登录态显示 Public，但匿名访问账号主页、仓库和 raw 文件仍返回 404，**尚不能作为已验证的公开交付地址**。 |
| Laravel 首页 | [ALB HTTP 地址](http://poper-test-alb-565988149.ap-northeast-1.elb.amazonaws.com/) | 首页与 `/healthz` 已实测 HTTP 200；测试环境使用 HTTP。 |
| CI/CD 工作流 | [release.yml](https://github.com/fafafafa868888/poper-test/actions/workflows/release.yml) | 配置已提交，但账号限制使 GitHub Actions 返回 HTTP 422 `Actions has been disabled for this user`；没有成功运行记录。 |

## AWS 平台功能入口

项目区域为 `ap-northeast-1`（东京），资源名前缀为 `poper-test`。下面列出控制台入口及可用于检索的已知资源名；动态生成的 bucket 名可从 Terraform 输出读取。

| 功能 | 东京区域 Console 入口 | 资源线索 / 验证重点 |
| --- | --- | --- |
| 网络与安全组 | [VPC](https://console.aws.amazon.com/vpc/home?region=ap-northeast-1) | `poper-test-vpc`；公有 ALB 子网与私有数据库子网。 |
| 负载均衡与目标健康 | [EC2 / Load Balancers](https://console.aws.amazon.com/ec2/home?region=ap-northeast-1) | `poper-test-alb`；查看 listener、target group 与健康目标。 |
| PHP 应用与定时扩缩容 | [ECS](https://console.aws.amazon.com/ecs/v2/home?region=ap-northeast-1) | `poper-test-cluster`、`poper-test-web`；查看 task、service、Auto Scaling scheduled actions。 |
| 镜像版本 | [ECR](https://console.aws.amazon.com/ecr/repositories?region=ap-northeast-1) | `poper-test/app`、`poper-test/web`、`poper-test/backup`；核对镜像 digest。 |
| PostgreSQL | [RDS](https://console.aws.amazon.com/rds/home?region=ap-northeast-1) | `poper-test-postgres`；单 AZ、私有访问、最小规格。 |
| 数据库 dump 与 Terraform state | [S3](https://console.aws.amazon.com/s3/home?region=ap-northeast-1) | 备份 bucket 名见 `foundation` 输出 `backup_bucket_name`；state bucket 名见 `bootstrap` 输出 `state_bucket_name`。 |
| 动态配置与发布 | [AWS AppConfig](https://console.aws.amazon.com/systems-manager/appconfig/?region=ap-northeast-1) | 应用 `poper-test`；临时内容已发布并恢复默认。 |
| 每日备份调度 | [EventBridge Scheduler](https://console.aws.amazon.com/scheduler/home?region=ap-northeast-1) | group `poper-test-backup`、schedule `poper-test-daily-backup`；当前为 `cron(0 2 * * ? *)`、`Asia/Tokyo`。 |
| 备份控制器 | [Lambda](https://console.aws.amazon.com/lambda/home?region=ap-northeast-1) | `poper-test-backup-controller`；查看调用与失败分类。 |
| 访问、应用、备份日志 | [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1) | 在 Log groups 中查 `/poper-test/app`、`/poper-test/web`、`/poper-test/backup` 及 ALB 日志组。 |
| ECS / ALB 指标与看板 | [CloudWatch Dashboards](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1) | 在 Dashboards 中查 `poper-test-operations`；底层 RunningTaskCount、CPU 指标已有数据。 |
| 应用、ALB、备份告警 | [CloudWatch Alarms](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1) | 在 Alarms 中查 `poper-test-application-error`、`poper-test-alb-exact-500-ratio`、`poper-test-backup-failed` 及 action history。 |
| 告警与发布通知 | [SNS](https://console.aws.amazon.com/sns/v3/home?region=ap-northeast-1) | topic `poper-test-alerts`；两个邮件订阅仍为 `PendingConfirmation`。 |
| 运行时密钥 | [Secrets Manager](https://console.aws.amazon.com/secretsmanager/home?region=ap-northeast-1) | RDS 托管密码与 Laravel `APP_KEY`；只核对资源存在和权限，不展示值。 |

## 文档、架构图与告警演示

| 原题交付项 | 仓库入口 | 当前状态 |
| --- | --- | --- |
| 架构图（图片） | [架构图](architecture.png)、[架构说明](architecture.md) | 已生成。 |
| 核心操作流程 | [部署、验收、清理手册](runbook.md) | 包含 Terraform 部署、镜像发布、备份恢复及清理步骤。 |
| 告警触发方法 | [运行手册：告警触发](runbook.md#告警触发) | 说明应用 `ERROR`、ALB 500 比例和备份失败的受控触发方法；测试路由已关闭。 |
| 触发后的实际记录 | [部署与验收记录](deployment-evidence.md)、[逐项验收清单](acceptance.md) | 三种告警均实测进入 `ALARM` 并恢复 `OK`，CloudWatch action history 显示 SNS topic action 执行成功。 |
| 告警触发后的截图 | 待补 | 仓库目前**没有告警截图**。需要从 CloudWatch 历史记录或重新受控触发后截取告警状态、时间和资源名；不得用文字记录冒充截图。 |

## 提交前仍需完成

1. 恢复仓库的匿名可见性，并实际运行 GitHub Actions；目前 GitHub Support 工单尚未提交，账号已开启 2FA，但短信验证页提示请求次数限制。由账号所有者稍后完成验证并提交 404/422 的复现证据。
2. 两位收件人确认 SNS 邮件订阅后，重新触发通知并保存邮件送达证据；当前仅验证了 CloudWatch → SNS topic action，没有邮件送达记录。
3. 补齐原题明确要求的告警触发后截图，以及需要交付的 AWS Console 截图；检查截图没有密钥、密码、私有配置或账号凭据。
4. 按原题要求将本页、文档、架构图和代码整理为可发送的交付包，或发布为可匿名打开的在线文档。正式东京时间 17:00/18:00 的扩缩容窗口、02:00 的每日备份窗口仍待观察；临时调度动作已验证机制。
