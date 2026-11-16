# 东京区域部署进度与 Terraform 计划

更新日期：2026-11-16。使用本机 `AKSK.env` 确认测评账号身份和东京区域资源。三个 stack 均已执行 `terraform apply`；`workload` 首次发布通过手工构建、ECR 推送和 digest 固定镜像完成，随后两次由 GitHub Actions 自动更新。公开仓库为 [twink7e/aws-test](https://github.com/twink7e/aws-test)，匿名仓库和 README 均为 HTTP 200；两个 Actions Secrets 和四个 Variables 已配置。[run 43813162697](https://github.com/twink7e/aws-test/actions/runs/43813162697) 与 [run 43815555640](https://github.com/twink7e/aws-test/actions/runs/43815555640) 均完成且成功。

| Stack | 检查结果 | 实际动作与待办 |
| --- | --- | --- |
| `bootstrap` | 已通过 `fmt`、`validate`、`plan` 并在东京账号应用成功。 | 已创建 6 项：Terraform state S3 bucket 及其加密、版本化、公开访问阻止等配置；无修改或删除。 |
| `foundation` | 已通过 `fmt`、`validate`，使用真实 S3 backend 完成 `plan/apply`。 | 首次创建 87 项，包括 VPC/子网、ALB、单 AZ RDS、ECR、备份 S3、IAM、AppConfig、SNS、日志和告警；随后补建 7 天保留期日志组 1 项。测试中应用错误告警周期从 300 秒改为 60 秒，仅修改 1 项、无新增或销毁；临时 AppConfig 内容也已恢复默认。最终详细计划无差异。 |
| `workload` | `fmt`、`validate` 通过；备份控制器 7 项本地测试通过。 | 首次创建 23 项。三张 `linux/arm64` 镜像已手工构建、测试并推送 ECR，以 digest 固定版本完成远端 `apply`。临时备份 Scheduler 已恢复东京时间 02:00；备份失败告警周期从 300 秒改为 60 秒，仅修改 1 项、无新增或销毁。临时扩缩容表达式的 `apply` 为 0 新增、2 修改、0 销毁；恢复默认表达式的 `apply` 也是 0 新增、2 修改、0 销毁。手工验收后的详细计划无差异；其后两次 Actions 发布均通过 Terraform 更新 digest，并等待 ECS 稳定。第二次部署任务定义 `poper-test-web:5`。 |

已创建的 RDS 为 PostgreSQL 17.11、`db.t4g.micro`、20 GiB、`multi_az = false`、`publicly_accessible = false`，存储自动增长关闭。六个自建 IAM 角色均以 `itv-poper-test-` 开头并附加测评账号要求的 `InterviewCandidate-Boundary`；另有两个 AWS 服务关联角色。SNS 告警收件地址已改为 `minghe.yin+shuo.xiao@poper.co` 和 `te.qi+shuo.xiao@poper.co`；两位收件人均须确认新订阅，尚无收件箱送达证据。此次 Terraform 变更为 2 项新增、2 项销毁，后续详细计划无差异；旧别名的一条未确认订阅仍暂列 AWS SNS，等待自动过期。

计划文件和真实变量文件保留在本机，均由 Git 忽略。`bootstrap` 的本地 state 也需安全保存。ALB 首页与 `/healthz` 实测 HTTP 200；手工备份写入 S3 的 dump 为 16,664 字节，并在隔离的 PostgreSQL 17 实例恢复出 9 张表和 3 条 migration 记录。临时 Scheduler 于东京时间 12:52 启动备份任务，任务退出码为 0，S3 收到另一份 16,664 字节 dump；随后通过 Terraform 恢复 `cron(0 2 * * ? *)`、`Asia/Tokyo`。正式每天 02:00 的运行仍待观察。

应用 `ERROR` 告警在 2 条事件后进入 `ALARM`，并于 2026-11-16 03:53 UTC 恢复 `OK`；ALB 精确 HTTP 500 比例在 89.655% 时进入 `ALARM`，停止测试后恢复 `OK`。受控失败备份任务退出码为 1，Lambda 判定 `false`，`BackupFailed` 指标为 1，告警进入 `ALARM`，随后于 2026-11-16 11:58:27 UTC+08 恢复 `OK`。测试故障路由已关闭，两个路径均返回 404。AppConfig 临时内容 `Live update verified` 无须更改 ECS 任务定义便在首页显示，Terraform 恢复默认后首页再次显示 `Hello from AppConfig`；自动回滚仍待验证。扩缩容测试并恢复默认表达式后，手工验收时 `foundation` 与 `workload` 详细计划均以退出码 0 结束，无差异；随后 Actions 发布改变了 workload 的镜像 digest。完整观察结果见 [部署证据](deployment-evidence.md)。

定时扩缩容已用东京时间 13:10/13:13 的一次性动作验证：04:10:49 UTC 观察到 desired 2/running 1/pending 1、容量上下限 2/2；04:11:32 UTC running 2 且两个 ALB 目标健康；04:13:22 UTC desired/running 1/1、上下限 1/1。随后两项 AWS scheduled action 已核对为 `cron(0 17 * * ? *)` / `cron(0 18 * * ? *)`、`Asia/Tokyo`。第二次 Actions 发布后 ECS desired/running 为 1/1、pending 为 0、单 deployment、rollout `COMPLETED`，ALB 首页与 `/healthz` 再次返回 HTTP 200。正式 17:00/18:00 的实际窗口与 SNS 邮件送达仍需验证。持续计费的基础资源包括 RDS 和 ALB；应用 Fargate 平时运行一个最小任务，默认配置在 17:00–17:59 运行两个，备份任务仅执行时运行。评估完成后按 [运行手册](runbook.md) 销毁。
