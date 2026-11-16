# 东京部署与验收记录

记录日期：2026-11-16。区域：`ap-northeast-1`。本页记录已经观察到的结果；计划中的自动化和待完成的验收单独注明。

## 部署与发布

| 项目 | 已观察结果 |
| --- | --- |
| Terraform | `bootstrap` 创建 6 项资源；`foundation` 首次创建 87 项，随后增加 1 项日志组；`workload` 首次创建 23 项。测试中将应用错误告警周期由 300 秒改为 60 秒，`foundation` 仅修改 1 项；备份失败告警周期也由 300 秒改为 60 秒，`workload` 仅修改 1 项，两次均无新增或销毁。临时备份 Scheduler 已恢复默认表达式。临时扩缩容表达式及恢复默认表达式两次 `apply` 均为 0 新增、2 修改、0 销毁；最终 `foundation` 与 `workload` 计划均以 detailed exit code 0 结束，无差异。三个 stack 分别保存 state。 |
| 镜像发布 | PHP 应用、Nginx 和备份三张 `linux/arm64` 镜像已手工构建、测试并推送 ECR。`workload` 使用 ECR 镜像 digest 固定版本并完成 `terraform apply`。这是**手工首发**，不代表 CI/CD 已通过。 |
| ECS 服务 | 应用服务期望任务数和运行任务数均为 1；ALB 目标健康。应用任务定义设置 `nofile` soft/hard 为 131072。 |

## 访问与功能

- ALB：[`http://poper-test-alb-565988149.ap-northeast-1.elb.amazonaws.com/`](http://poper-test-alb-565988149.ap-northeast-1.elb.amazonaws.com/)。2026-11-16 实测首页和 `/healthz` 均返回 HTTP 200。
- 首页显示环境变量消息 `Hello from POPER test` 和 AppConfig 消息 `Hello from AppConfig`；`/healthz` 返回 `{"status":"ok"}`。
- CloudWatch Logs 已收到 Nginx JSON、Laravel/PHP-FPM、ALB JSON、备份和 Lambda 控制器日志。自定义 `X-Amzn-Trace-Id` 在 Nginx 与 Laravel 日志中均可查到；Container Insights 日志组保留期为 7 天。
- CloudWatch Dashboard 的底层指标已有真实数据：ECS/ContainerInsights `RunningTaskCount` 为 1.0，AWS/ECS `CPUUtilization` 有数据点；Dashboard 截图尚待整理。
- 8 个 CloudWatch Alarm 在受控测试前均为 `OK`。临时启用测试路由后，Laravel 产生 2 个 `ERROR` 事件，`poper-test-application-error` 进入 `ALARM`；25/25 次测试请求返回精确 HTTP 500，`poper-test-alb-exact-500-ratio` 因 89.655% 超过 10% 阈值进入 `ALARM`。测试后已关闭路由，两个路径均返回 404，ALB 比例告警恢复 `OK`；应用错误告警在 2026-11-16 03:53 UTC 恢复 `OK`。为缩短评估与恢复窗口，`foundation` 将应用错误告警周期由 300 秒改为 60 秒，此次 `apply` 为 1 项修改、无新增和销毁。SNS 邮件送达尚未验证。
- 受控失败备份任务退出码为 1；Lambda 控制器将任务结果判定为 `false`，发出 `BackupFailed` 指标值 1。用户提供的 [CloudWatch History 截图](evidence/cloudwatch-backup-failed-history.png) 显示 `poper-test-backup-failed` 于 2026-11-16 03:47:32 UTC 从 `OK` 进入 `ALARM`，同一时刻成功执行 `poper-test-alerts` SNS topic action，并于 03:58:27 UTC 从 `ALARM` 恢复 `OK`。为缩短恢复窗口，`workload` 将该告警周期由 300 秒改为 60 秒，此次 `apply` 为 1 项修改、无新增和销毁。两个 SNS 邮件订阅尚未确认，因此没有邮件送达证据。
- 三个告警的 CloudWatch action history 均记录在进入 `ALARM` 时成功执行 `poper-test-alerts` SNS topic action。该记录证明告警向 SNS topic 发起动作，不代表邮件已送达；两个订阅仍为 `PendingConfirmation`。
- AppConfig 临时内容 `Live update verified` 已在首页出现，期间 ECS 任务定义未变化，证明应用动态获取配置。随后通过 Terraform 恢复默认内容，首页又显示 `Hello from AppConfig`。此测试不等同于 AppConfig 自动回滚验证。

## 调度、备份与恢复

- 2026-11-16 用 Terraform 将两项 Application Auto Scaling scheduled action 临时设为 `at(2026-11-16T13:10:00)` 和 `at(2026-11-16T13:13:00)`，时区均为 `Asia/Tokyo`；`apply` 为 0 新增、2 修改、0 销毁。触发前 ECS desired/running 为 1/1，scalable target 最小/最大容量为 1/1。
- 04:10:49 UTC（东京时间 13:10:49）观察到 ECS desired 2、running 1、pending 1，容量上下限 2/2；04:11:32 UTC（13:11:32）desired/running 均为 2，两个 ALB target 均健康；04:13:22 UTC（13:13:22）desired/running 回到 1/1，容量上下限回到 1/1。这验证了定时扩容和缩容机制。
- 测试后 Terraform 以 0 新增、2 修改、0 销毁恢复默认值。AWS `describe-scheduled-actions` 确认两项表达式分别为 `cron(0 17 * * ? *)`、`cron(0 18 * * ? *)`，时区均为 `Asia/Tokyo`；scalable target 上下限与 ECS desired/running 均为 1/1。最终 workload 详细计划退出码 0、无差异。正式 17:00/18:00 窗口尚未观察。
- 手工调用备份控制 Lambda 成功启动并完成 Fargate 备份任务，S3 收到 16,664 字节的 PostgreSQL 自定义格式 dump。
- 临时 Scheduler 在 2026-11-16 东京时间 12:52 自动启动备份任务；任务退出码为 0，S3 收到 16,664 字节的 dump。随后通过 Terraform 将计划恢复为 `cron(0 2 * * ? *)`、时区 `Asia/Tokyo`；正式每天 02:00 的触发仍需单独观察。
- 将手工备份产生的 dump 恢复到隔离的本地 PostgreSQL 17 实例，确认 9 张表和 3 条 Laravel migration 记录。

## 尚待完成的验收

- 两个 SNS 邮件订阅仍为 `PendingConfirmation`；收件人须先确认订阅，之后才能验证告警邮件送达。
- 备份失败告警的 CloudWatch History 截图已保存；应用 `ERROR` 和 ALB 精确 HTTP 500 的触发后截图仍待用户上传。
- 告警邮件、正式 17:00/18:00 窗口、每天 02:00 正式定时备份及 AppConfig 自动回滚仍需单独验证；已受控触发的应用错误、ALB 500 比例和备份失败告警目前均为 `OK`。
- [twink7e/aws-test](https://github.com/twink7e/aws-test) 的公开权限已核实，两个 Actions Secrets 和四个 Variables 已配置。本次 `main` 推送后需核对匿名代码访问，并实际运行 `release` 工作流核对构建、测试、ECR 推送、Terraform 发布与通知。截至本次记录，没有 CI/CD 成功运行记录。
- 迁移背景：旧测试账号的仓库匿名访问曾返回 404，Actions 触发曾返回 HTTP 422；此记录不代表新仓库存在同样限制。
