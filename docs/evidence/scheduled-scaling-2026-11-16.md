# 东京时间定时扩缩容验收

区域：`ap-northeast-1`。Application Auto Scaling 的 ECS scalable target 与两条 scheduled action 均由 `infra/terraform/workload/autoscaling.tf` 管理。正式表达式为 `cron(0 17 * * ? *)` 与 `cron(0 18 * * ? *)`，时区均为 `Asia/Tokyo`；17:00 将最小/最大任务数设为 2/2，18:00 设回 1/1。

## 2026-11-16 正式 17:00 扩容

| 东京时间（JST） | AWS 实测 |
| --- | --- |
| 16:58:42 | ECS `poper-test-web` desired/running/pending 为 1/1/0；scalable target 最小/最大容量为 1/1。两条正式 cron 均启用且时区为 `Asia/Tokyo`。 |
| 17:00:45 左右 | Application Auto Scaling activity 记录容量上下限调整到 2/2，并开始把 desired count 设为 2。 |
| 17:00:52 | ECS service event 记录启动第二个任务。 |
| 17:01:47 | ECS service event 记录向 ALB target group 注册第二个目标。 |
| 17:01:56 | ECS service event 记录达到 steady state。 |
| 17:02:52 | ECS desired/running/pending 为 2/2/0；ALB target group 内两个目标均为 `healthy`。 |

上述结果验证正式 17:00 计划实际改变容量并成功提供两个健康副本。17:00 触发到任务稳定有约 1 分 56 秒的启动与健康检查延迟。正式 18:00 缩容动作尚未到触发时间；此前已用同一 Terraform scheduled action 的一次性表达式验证缩容机制。

## 同日较早的一次性双向演练

为避免等候正式窗口，曾通过 Terraform 临时把两条表达式设为东京时间 13:10 与 13:13 的一次性动作。13:10:49 观察到 desired/running/pending 为 2/1/1、容量上下限 2/2；13:11:32 观察到 running 2 且两个 ALB 目标健康；13:13:22 观察到 desired/running 回到 1/1、容量上下限回到 1/1。随后通过 Terraform 恢复上面的正式 cron，`terraform plan -detailed-exitcode` 无差异。
