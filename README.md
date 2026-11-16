# POPER 中级运维岗技术课题

本仓库是面试题的可复现交付物。目标是在 AWS 东京区域，用 Terraform 声明全部云资源；用 GitHub Actions 构建 Docker 镜像并发布 Laravel 13 / PHP 8.4 应用；通过 CloudWatch 和 SNS 提供可验证的日志、告警和通知；每日把 PostgreSQL 全量逻辑备份写入 S3。

当前阶段是**云端验收**。AWS 东京区域已应用 `bootstrap` 6 项、`foundation` 88 项和 `workload` 首次 23 项资源；三张 `linux/arm64` 镜像已手工构建、推送 ECR，并以 digest 完成 Terraform 发布。ALB 首页与 `/healthz` 均返回 200；手工备份的 dump 已在隔离的 PostgreSQL 17 实例恢复，临时 Scheduler 也成功触发备份。临时定时动作实测 ECS 从 1 个任务扩至 2 个健康目标，再缩回 1 个；两项动作已恢复为东京时间 17:00/18:00 的每日表达式。应用 `ERROR`、ALB HTTP 500 比例及备份失败告警均已受控触发，随后全部恢复 `OK`。AppConfig 临时内容已在首页动态显示，无须更改 ECS 任务定义，默认配置已通过 Terraform 恢复且再次显示在首页。测试故障路由已关闭；`foundation` 和 `workload` 最终详细计划均无变更。

新仓库 [twink7e/aws-test](https://github.com/twink7e/aws-test) 的公开权限已核实，两个 Actions Secrets 和四个 Variables 已配置。本次迁移的 `main` 推送完成后，还需核对代码的匿名访问与 Actions 运行结果；截至本次文档更新，工作流尚未实跑。AWS 的手工部署和实测结果不受仓库迁移影响。两个 SNS 订阅仍待确认，不能证明邮件送达。不要把 AWS 凭证、Terraform state、数据库密码或评估题原件提交到公开仓库。

## 完成标准

1. ALB 公开访问 Laravel 首页；首页展示指定的非敏感环境变量和 AppConfig 动态配置。应用运行在 ECS Fargate，数据库是私有子网中的 RDS PostgreSQL。
2. `main` 分支推送触发 GitHub Actions：测试、构建 PHP-FPM/Nginx/备份镜像、推送 ECR、通过 Terraform 更新 ECS 任务定义，并发出成功或失败通知。Actions 使用新仓库 Secrets 中的 AWS AK/SK。
3. 东京时间每天 17:00 扩至 2 个应用任务，18:00 缩至 1 个；每天 02:00 运行 `pg_dump -Fc`，将完整数据库 dump 写入 S3，并能通过 `pg_restore` 恢复。
4. 收集 Nginx JSON 访问日志、Laravel/PHP-FPM 日志、ALB 访问日志、备份日志；访问日志带 `X-Amzn-Trace-Id`。CloudWatch 提供资源和 HTTP 状态看板、应用 `ERROR` 与 HTTP 500 比例告警，备份及发布异常通知。
5. 所有相关资源有明确清理路径。交付架构图、操作说明、告警触发方法与实际验证证据。

## 仓库布局

| 路径 | 用途 |
| --- | --- |
| `infra/terraform/bootstrap/` | 首次建立加密、版本化的 S3 Terraform state bucket，使用独立本地 state。 |
| `infra/terraform/foundation/` | 长寿命 AWS 基础资源：VPC、ALB、RDS、S3、ECR、ECS cluster、运行时 IAM、AppConfig、SNS 和日志组。 |
| `infra/terraform/workload/` | 与发布版本相关的 ECS 服务、定时扩缩容、备份调度和执行、CloudWatch 指标/告警/看板。 |
| `app/` | Laravel 13 / PHP 8.4 示例应用、Composer 依赖锁定文件、Docker 构建上下文及本地验证。 |
| `backup/` | PostgreSQL 全量逻辑备份容器及上传/校验脚本。 |
| `.github/workflows/` | 主分支 CI/CD：测试、镜像构建、ECR 推送、Terraform 发布、SNS 通知；AWS 凭证从 Actions Secrets 读取。 |
| `docs/architecture.md` | 云资源边界、请求/发布/备份/观测数据流。 |
| `docs/architecture.png` | 可直接随交付物提交的架构图片。 |
| `docs/runbook.md` | 从账号准备到上线、验收、恢复、清理的逐步操作。 |
| `docs/acceptance.md` | 面试题逐项验收清单，标明本地实现与云端证据的状态。 |
| `docs/deployment-evidence.md` | 东京区域手工部署、应用访问、备份恢复与告警的实测记录。 |
| `docs/submission.md` | 按原题提交格式汇总仓库、AWS Console 入口、文档、告警演示和待补证据。 |
| `docs/terraform-feasibility.md` | 逐项说明 Terraform 可实现的操作、扩缩容边界和账号权限约束。 |
| `docs/plan-summary.md` | 东京测评账号的 Terraform 应用进度与待云端验收项。 |
| `docs/repository-map.md` | 每个受版本控制的目录和文件的具体作用。 |
| `scripts/render_architecture.py` | 从仓库内的图形定义重新生成架构 PNG。 |
| `.gitignore`、`.editorconfig` | 防止本地状态/密钥误提交，统一文本格式。 |

完整的**逐文件说明**见 [仓库资源清单](docs/repository-map.md)，不是只有上面的目录概览。

## Terraform 资源边界

三个 stack 独立保存 state，依次执行 `bootstrap → foundation → workload`。`foundation` 不随每次镜像发布重建数据库或网络；`workload` 从 foundation 的只读输出获取 ARN、网络、仓库和日志组。应用镜像使用 ECR digest 固定版本，`terraform apply` 是实际发布步骤。每次发布共用同一个 GitHub Actions concurrency 组，避免互相覆盖。

定时扩缩容仅控制 ECS 服务的任务数。默认配置在东京时间 17:00 到 17:59 目标为 2，其他时间目标为 1。2026-11-16 曾用 13:10/13:13 的一次性动作验证扩容和缩容：两个目标在扩容后均健康，缩容后期望/运行任务数回到 1。测试后两项 AWS scheduled action 已恢复默认表达式和时区，Terraform 详细计划无差异；实际 17:00/18:00 窗口尚未观察。任务启动、连接排空和停止宽限会让实际任务数稍晚于触发时刻变化。RDS 存储如果启用自动增长，则**不能原地缩小容量**；本题默认不启用该功能，以免产生不可逆的容量增长。Fargate 的 `nofile` 在任务定义中提高，但仍受 Fargate 平台上限约束。

备份容器默认使用 Fargate 的 20 GiB 临时磁盘。如果完整 dump 超过可用空间，备份会失败并告警；可通过 `backup_ephemeral_storage_gib` 为下一版备份任务定义配置 21–200 GiB，并评估额外费用。更大的数据库也可以改成流式上传，但当前实现先落临时文件再核对 S3 大小，便于面试验收。

当前账号的自建 IAM 角色必须以 `itv-` 开头并附加指定的权限边界，且未授予 Step Functions、SQS 权限。因此备份使用 Scheduler → Lambda 控制器 → ECS，并用任务停止事件、CloudWatch 与 SNS 检查和告警。完整的可实现性与限制见 [Terraform 实现边界](docs/terraform-feasibility.md)。

## 成本与高可用取舍

本次是短期面试环境，以**满足运行要求的最小 Fargate 规格**为目标，不建设生产级跨 AZ 高可用：RDS 使用单 AZ `db.t4g.micro`、20 GiB 存储；应用 Fargate 任务默认 `0.25 vCPU / 0.5 GiB`，通常只运行 1 个任务；每日备份任务也为 `0.25 vCPU / 0.5 GiB`，只在执行时计费。PHP-FPM 最多启用 2 个 worker，控制内存。没有 RDS Multi-AZ、热备数据库或 NAT Gateway。高可用能力、自动故障转移和峰值余量不在本次验收目标内。

ALB 必须连接两个不同 AZ 的子网，因此网络中仍保留两个公有子网；这不代表 RDS 开启 Multi-AZ，也不代表 ECS 平时有两个应用副本。RDS 部署在隔离的私有子网；Fargate 任务部署在公有子网并分配公有 IP，用于拉取 ECR 镜像和访问 AWS API，入站安全组只接受来自 ALB 的请求。生产环境如需更强隔离，可改为私有任务加 VPC endpoints 或 NAT，并重新评估费用。

## 需要提供的输入

AWS 东京区域凭证已在本机 `AKSK.env`，告警别名已确定为 `zhangsan`，首页使用非敏感的 `DEMO_MESSAGE` 默认值。新 GitHub 仓库公开权限与 Actions 配置已就绪；后续仍需要：

| 输入 | 用途 | 安全方式 |
| --- | --- | --- |
| 代码推送与 Actions 实跑 | 让面试官无需登录查看代码，并验证自动发布。 | [新仓库](https://github.com/twink7e/aws-test) 的公开权限已核实；本次 `main` 推送后核对匿名代码访问、自动触发及手动发布结果。 |
| Actions Variables 与 AWS AK/SK Secrets | 让工作流发布镜像和执行 workload Terraform。 | 新仓库的两个 Secrets 和四个 Variables 已配置；密钥不得写入 Git。测试结束后删除 Secrets 并轮换/停用该 AK/SK。 |
| 两位告警收件人的订阅确认 | SNS 发布邮件前必须分别确认。 | 两个订阅仍为 `PendingConfirmation`；收件人须点击 AWS 确认邮件。当前已验证 CloudWatch 告警触发，未验证邮件送达。 |
| 可选域名与同区域 ACM 证书 ARN | 如果要 HTTPS 和友好网址。 | 没有证书时使用 ALB 提供的 HTTP DNS 名称。 |

云资源参数通过 `terraform.tfvars`、`backend.hcl` 传入；AWS 密钥留在本地 `AKSK.env`，发布时另存入 GitHub Actions Secrets，均不进入受版本控制的文件。示例文件可复制后填写；实际变量文件被 `.gitignore` 排除。部署与销毁命令见 [运行手册](docs/runbook.md)。

## 相关文档

- [架构和资源边界](docs/architecture.md)
- [架构图片](docs/architecture.png)
- [逐项验收清单](docs/acceptance.md)
- [东京部署与验收记录](docs/deployment-evidence.md)
- [交付包索引与 AWS Console 入口](docs/submission.md)
- [Terraform 实现边界与缩容限制](docs/terraform-feasibility.md)
- [东京区域 Terraform 部署进度](docs/plan-summary.md)
- [逐文件资源清单](docs/repository-map.md)
- [部署、验证与清理手册](docs/runbook.md)

## AI 辅助说明

本仓库使用 Codex 辅助架构设计、Terraform/Docker/Laravel/备份代码编写和文档整理。AI 减少了重复配置的编写，并把“生成实现→静态检查→容器测试→云端验证”的反馈循环集中在同一工作流；没有量化节省的时间。

采用自然语言驱动的人机协作，包含 Vibe Coding 式的快速迭代：用户确定东京区域、最小规格、成本和安全边界，Codex 落盘实现并执行检查，结果再按 Terraform 计划、容器冒烟和 AWS 实测逐项核对。关键提示词示例（原需求意译）：「用 Terraform 落盘东京区域资源，按最小规格部署 Laravel 13/PHP 8.4 到 ECS Fargate，配置定时扩缩容、数据库备份和 CloudWatch/SNS 告警，并写清每个文件的用途。」工作流示例：需求拆解 → 三层 Terraform stack → `fmt/validate/plan` → Docker 测试 → AWS 部署 → 告警与恢复演练 → 记录证据。

静态检查、本地容器测试和已观察到的 AWS 运行结果分别记录在 [验收清单](docs/acceptance.md) 与 [部署证据](docs/deployment-evidence.md)；GitHub Actions 运行和邮件送达尚未验证。
