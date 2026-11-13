# 测评验收清单

“已实现”表示仓库已有配置或代码，并通过本地静态/容器检查；“待云端验证”表示需要真实 AWS 账号、GitHub 仓库或邮件确认后才能提供证据。提交前按此表逐项核对。

| 验收项 | 实现位置 | 当前状态与证据 |
| --- | --- | --- |
| AWS 东京区域、资源可复现 | `infra/terraform/bootstrap/`、`foundation/`、`workload/` | 已实现；三套 Terraform `validate` 通过。目标账号只读计划见 `docs/plan-summary.md`：bootstrap 创建 6 项、foundation 创建 87 项，均无修改/删除；待 AWS `apply` 和服务验收。 |
| 成本优先、单 AZ 小规格 | `foundation/database.tf`、`workload/ecs.tf`、`workload/backup.tf` | RDS 单 AZ `db.t4g.micro`，应用和备份任务均为 Fargate 最小的 0.25 vCPU/0.5 GiB；未建设 RDS Multi-AZ 或热备。ALB 仍按服务要求跨两个 AZ 子网。 |
| Laravel 13、PHP 8.4、Fargate Docker 部署 | `app/Dockerfile`、`workload/ecs.tf`、`app/docker/nginx.Dockerfile` | ARM64 镜像与本地 HTTP 冒烟测试通过；待 ECS 部署。 |
| 首页显示非敏感环境变量 | `app/config/demo.php`、`app/resources/views/home.blade.php`、`workload/variables.tf` | 已选 `DEMO_MESSAGE` 并提供默认值；待 ECS 实际页面截图。 |
| AppConfig 动态配置、发布、回滚与通知 | `foundation/appconfig.tf`、`foundation/notifications.tf`、`app/app/Support/AppConfig.php` | 本地模拟 Agent 值通过；待真实配置更新、回滚和 SNS 邮件验证。 |
| Nginx JSON 访问日志及 `X-Amzn-Trace-Id` | `app/docker/nginx.conf`、`app/docker/smoke.sh` | 本地日志检验通过；待 CloudWatch Logs 截图。 |
| Laravel/PHP-FPM、ALB、备份日志进入 CloudWatch | `app/config/logging.php`、`app/docker/fpm.conf`、`foundation/observability.tf`、`workload/ecs.tf` | 已配置保留期和投递；待 AWS 实际日志验证。 |
| 东京时间 17:00–17:59 为 2 个任务，其他时间 1 个 | `workload/autoscaling.tf`、`workload/data.tf` | 已实现，容量上下限由定时操作管理；待跨时间窗口验证。 |
| RDS PostgreSQL 每日全量 dump 到 S3 | `foundation/database.tf`、`workload/backup.tf`、`backup/` | `pg_dump -Fc` 容器及 Scheduler → Lambda → ECS 已实现；待手动执行和恢复演练。 |
| 备份失败告警 | `workload/backup.tf`、`workload/backup_controller.py`、`workload/monitoring.tf` | 控制器检查 `RunTask.Failures` 与任务退出码；Scheduler、EventBridge、Lambda 自身错误也有告警。7 项本地控制器测试通过；待云端触发并截图。 |
| `main` 推送自动构建 ECR 镜像并发布 ECS | `.github/workflows/release.yml` | 已实现 Actions Secrets AK/SK、镜像 digest、ECS 稳定性检查；`actionlint` 和本地镜像测试通过。待真实 GitHub Actions run。 |
| 发布成功/失败通知 | `.github/workflows/release.yml`、`foundation/notifications.tf` | 已配置 SNS；待确认收件人并验证邮件。AWS 认证本身失败时，SNS 通知 job 也可能无法认证，应同时查看 GitHub Actions 失败状态。 |
| ECS 副本、CPU、内存和 ALB HTTP 状态看板 | `workload/monitoring.tf` | 已配置 Dashboard；待真实指标和截图。 |
| 应用 `ERROR` 告警 | `foundation/observability.tf`、`app/routes/web.php` | 已配置；本地故障路由可产生 JSON `ERROR`，待 CloudWatch/SNS 验证。 |
| ALB 精确 HTTP 500 比例超过 10% 告警 | `workload/monitoring.tf`、`foundation/observability.tf` | 已配置 JSON ALB access log metric filter + metric math；待真实流量验证，日志投递会有延迟。 |
| 容器 `nofile` 限制 | `workload/ecs.tf`、`workload/backup.tf` | 已在任务定义设置 soft/hard 131072；待运行任务内验证。 |
| Terraform 可实现性和缩容限制 | `docs/terraform-feasibility.md` | 已逐项说明，ECS 可按计划缩到 1 个任务；RDS 存储不可原地缩小。 |
| 架构图、资源说明和操作手册 | `docs/architecture.png`、`docs/repository-map.md`、`docs/runbook.md` | 已生成并核对；实际 AWS Console URL 和告警截图待部署后补齐。 |
| 公开 GitHub 仓库链接与清理 | `README.md`、`docs/runbook.md` | 待创建独立仓库、推送；演示结束按 workload → foundation → bootstrap 顺序销毁。 |
