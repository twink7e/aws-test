# 测评验收清单

“已实现”表示仓库已有配置或代码，并通过本地静态/容器检查；已完成的云端及 GitHub Actions 观察结果按项列出，其余仍须正式定时窗口或邮件确认。详细记录见 [部署证据](deployment-evidence.md)。

| 验收项 | 实现位置 | 当前状态与证据 |
| --- | --- | --- |
| AWS 东京区域、资源可复现 | `infra/terraform/bootstrap/`、`foundation/`、`workload/` | 三套 Terraform `validate` 通过；东京区域已应用 `bootstrap` 6 项、`foundation` 88 项（初次 87 项、日志保留期补充 1 项）、`workload` 首次 23 项。后续告警周期调整分别在 foundation/workload 各修改 1 项、无新增或销毁；临时扩缩容表达式的 Terraform `apply` 为 0 新增、2 修改、0 销毁，恢复默认表达式的 `apply` 也是 0 新增、2 修改、0 销毁。手工验收结束时 `foundation` 和 `workload` 详细计划均无差异；其后 Actions 更新 workload 镜像 digest。详见 [部署进度](plan-summary.md)。 |
| 成本优先、单 AZ 小规格 | `foundation/database.tf`、`workload/ecs.tf`、`workload/backup.tf` | RDS 单 AZ `db.t4g.micro`，应用和备份任务均为 Fargate 最小的 0.25 vCPU/0.5 GiB；未建设 RDS Multi-AZ 或热备。ALB 仍按服务要求跨两个 AZ 子网。 |
| Laravel 13、PHP 8.4、Fargate Docker 部署 | `app/Dockerfile`、`workload/ecs.tf`、`app/docker/nginx.Dockerfile` | 三张 ARM64 镜像已手工首发，随后由 GitHub Actions 两次自动构建并推送 ECR；第二次部署的 ECS 任务定义为 `poper-test-web:5`，服务稳定且运行 1 个应用任务。ALB 目标健康；首页与 `/healthz` 均返回 HTTP 200。 |
| 首页显示非敏感环境变量 | `app/config/demo.php`、`app/resources/views/home.blade.php`、`workload/variables.tf` | ECS 实际首页显示 `DEMO_MESSAGE` 的 `Hello from POPER test`。 |
| AppConfig 动态配置、发布、回滚与通知 | `foundation/appconfig.tf`、`foundation/notifications.tf`、`app/app/Support/AppConfig.php` | 首页在不变更 ECS 任务定义的情况下显示临时内容 `Live update verified`，通过 Terraform 恢复后再次显示 `Hello from AppConfig`。自动回滚和 SNS 邮件仍待验证。 |
| Nginx JSON 访问日志及 `X-Amzn-Trace-Id` | `app/docker/nginx.conf`、`app/docker/smoke.sh` | CloudWatch 中已看到 Nginx JSON 日志，自定义 `X-Amzn-Trace-Id` 可在 Nginx 与 Laravel 日志中查到；截图待整理。 |
| Laravel/PHP-FPM、ALB、备份日志进入 CloudWatch | `app/config/logging.php`、`app/docker/fpm.conf`、`foundation/observability.tf`、`workload/ecs.tf` | CloudWatch Logs 已收到 Nginx、Laravel/PHP-FPM、ALB JSON、备份及 Lambda 控制器日志；截图待整理。 |
| 东京时间 17:00–17:59 为 2 个任务，其他时间 1 个 | `workload/autoscaling.tf`、`workload/data.tf` | 2026-11-16 以东京时间 13:10/13:13 的一次性定时动作实测：扩容前 desired/running 1/1、上下限 1/1；13:10:49 desired 2/running 1/pending 1、上下限 2/2；13:11:32 running 2 且两个 ALB 目标健康；13:13:22 desired/running 1/1、上下限 1/1。验证了定时扩容和缩容机制；两项 AWS 动作已恢复默认 cron 和 `Asia/Tokyo`，当前上下限与 ECS desired/running 均为 1/1。正式 17:00/18:00 窗口尚未观察。 |
| RDS PostgreSQL 每日全量 dump 到 S3 | `foundation/database.tf`、`workload/backup.tf`、`backup/` | 手工 Lambda → ECS 备份成功，S3 dump 为 16,664 字节；隔离 PostgreSQL 17 恢复出 9 张表和 3 条 migration 记录。临时 Scheduler 于东京时间 12:52 触发备份任务，退出码 0，S3 再次收到 16,664 字节 dump；之后通过 Terraform 恢复 `cron(0 2 * * ? *)`、`Asia/Tokyo`。正式 02:00 运行仍待观察。 |
| 备份失败告警 | `workload/backup.tf`、`workload/backup_controller.py`、`workload/monitoring.tf` | 受控任务退出码 1，Lambda 判定 `false`，`BackupFailed` 指标为 1，Alarm 进入 `ALARM`。告警周期从 300 秒改为 60 秒；2026-11-16 11:58:27 UTC+08 已恢复 `OK`。SNS 邮件待验证。 |
| `main` 推送自动构建 ECR 镜像并发布 ECS | `.github/workflows/release.yml` | 手工首发后，[首次 push run 43813162697](https://github.com/twink7e/aws-test/actions/runs/43813162697) 与 [原生 ARM run 43815555640](https://github.com/twink7e/aws-test/actions/runs/43815555640) 均成功；测试、三张镜像推送 ECR、digest 固定、Terraform apply 和 ECS 稳定性检查通过。第二次 PHP-FPM 构建耗时 1 分 27 秒，首次 QEMU 构建耗时 13 分 23 秒。 |
| 发布成功/失败通知 | `.github/workflows/release.yml`、`foundation/notifications.tf` | 两次成功的 Actions run 的 `notify` job 均通过，第二次的 SNS `Publish release result` 步骤成功；三个受控告警的 CloudWatch action history 也显示 SNS topic action 执行成功。新别名的两条邮件订阅均为 `PendingConfirmation`；收件箱送达未验证，失败通知分支尚未实测。AWS 认证失败时 SNS job 也可能无法认证，应同时查看 Actions 状态。 |
| ECS 副本、CPU、内存和 ALB HTTP 状态看板 | `workload/monitoring.tf` | 已配置 Dashboard；ECS/ContainerInsights `RunningTaskCount` 实测 1.0，AWS/ECS `CPUUtilization` 有数据点；看板截图待整理。 |
| 应用 `ERROR` 告警 | `foundation/observability.tf`、`app/routes/web.php` | 受控测试产生 2 条 `ERROR` 后进入 `ALARM`；告警周期由 300 秒改为 60 秒，2026-11-16 03:53 UTC 恢复 `OK`。测试故障路由已关闭；SNS 邮件尚未验证。 |
| ALB 精确 HTTP 500 比例超过 10% 告警 | `workload/monitoring.tf`、`foundation/observability.tf` | 实测 500 比例 89.655% 时进入 `ALARM`，关闭测试故障路由后恢复 `OK`；两个路径均返回 404。SNS 邮件尚未验证。 |
| 容器 `nofile` 限制 | `workload/ecs.tf`、`workload/backup.tf` | 已在任务定义设置 soft/hard 131072；待运行任务内验证。 |
| Terraform 可实现性和缩容限制 | `docs/terraform-feasibility.md` | 已逐项说明，ECS 可按计划缩到 1 个任务；RDS 存储不可原地缩小。 |
| 架构图、资源说明和操作手册 | `docs/architecture.png`、`docs/repository-map.md`、`docs/runbook.md` | 已生成并核对；东京 AWS Console 入口已列在 [交付索引](submission.md)，备份失败告警 History 截图已入库，应用 `ERROR` 与 ALB 精确 500 告警截图仍待补齐。 |
| 公开 GitHub 仓库链接与清理 | `README.md`、`docs/runbook.md` | [twink7e/aws-test](https://github.com/twink7e/aws-test) 的匿名仓库和 README 均为 HTTP 200，两次 push Actions 运行成功。演示结束按 workload → foundation → bootstrap 顺序销毁。 |
