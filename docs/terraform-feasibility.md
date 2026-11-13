# 题目要求与 Terraform 实现边界

目标区域固定为 `ap-northeast-1`。下表说明题目中每项操作的实现位置；「Terraform 支持」表示云资源及其配置可以声明化管理，实际程序执行和验收仍需运行镜像、工作流及测试流量。

| 要求 | 实现方式 | Terraform 支持与边界 |
| --- | --- | --- |
| 网络、安全组、ALB、ECS Fargate、RDS PostgreSQL、S3、ECR | `foundation` 创建长期资源，`workload` 创建任务定义与服务。 | 支持。ALB 要求两个不同 AZ 的公有子网；RDS 只有一个单 AZ 实例，Fargate 平时只有一个任务。 |
| 每天 17:00 扩为 2 个任务、18:00 缩为 1 个 | Application Auto Scaling 的 ECS scalable target 和两个东京时区的 scheduled action。 | 支持双向改变**应用任务数**。[AWS 定时扩缩容文档](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/scheduled-action-create-policy.html)。缩容可能因部署、连接排空和任务停止而晚于整点；[ECS 部署期间会暂停缩容](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)。 |
| 数据库容量的缩容 | 默认仅分配 20 GiB，不启用 RDS 存储自动增长。 | [RDS 不支持原地缩小已分配存储](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.Autoscaling.html)。若以后增长，只能建立较小的新实例并迁移或恢复数据。更换数据库实例规格可以配置，但可能造成中断，也不等于存储缩容。 |
| 容器 `ulimit` | 应用、Nginx、AppConfig Agent 和备份容器在 ECS task definition 中设置 `nofile` 的 soft/hard limit 为 131072。 | 支持，受 Fargate 允许的上限约束；[Fargate 任务定义参数](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html)。实际生效值在运行任务内验收。 |
| JSON 访问日志、Trace ID、PHP/FPM、ALB、备份日志 | Nginx 与 Laravel 输出 stdout/stderr，ECS `awslogs` 收集；ALB 使用 CloudWatch Logs vended delivery；日志组设置保留期。 | 日志组和投递支持 Terraform；日志格式由镜像内配置实现。[ALB 日志投递说明](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-logs.html)。 |
| 应用 `ERROR`、ALB 精确 HTTP 500 比例 >10%、备份失败 | CloudWatch Logs metric filter、metric math、CloudWatch alarms 和 SNS。备份由 Scheduler 调用 Lambda 启动 ECS，控制器检查 `RunTask` 响应，ECS `STOPPED` 事件再检查退出码；Scheduler、EventBridge 和 Lambda 自身错误也设告警。 | 支持。ALB access log 和 CloudWatch 指标存在投递及评估延迟；SNS 邮箱订阅需要收件人确认后才能投递。[Scheduler 指标](https://docs.aws.amazon.com/scheduler/latest/UserGuide/monitoring-cloudwatch.html)、[ECS 任务事件](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html)。 |
| 首页展示环境变量与 AppConfig 热更新、配置发布通知/回滚 | ECS 注入非敏感 `DEMO_MESSAGE`；AppConfig Agent sidecar 轮询托管 JSON；AppConfig 部署事件发送 SNS，并在部署窗口监控应用 `ERROR` 告警。 | AWS 配置支持 Terraform；首页读取配置要由 Laravel 代码实现。环境变量是进程启动时快照，修改它需要重新部署任务；AppConfig 动态值可由已运行任务读取。[Agent 集成](https://docs.aws.amazon.com/appconfig/latest/userguide/appconfig-integration-containers-agent.html)、[自动回滚窗口](https://docs.aws.amazon.com/appconfig/latest/userguide/monitoring-deployments.html)。 |
| `main` 推送后构建镜像、测试、推 ECR、发布 ECS、通知结果 | 新注册的普通 GitHub 账号运行 GitHub Actions 托管 runner；AWS AK/SK 存在仓库 Actions Secrets 中；Docker 构建 PHP、Nginx、备份镜像；workload Terraform apply 用 digest 发布。 | ECR、ECS 和应用资源由 Terraform 管理；GitHub 注册、仓库及 Actions Secrets/Variables 需要在新账号建立后配置。CI 工作流是代码仓库文件，不是 AWS Terraform 资源。没有常驻 CI 机器。 |
| Laravel 13 / PHP 8.4 构建 | PHP runtime 镜像包含锁定的 Composer 生产依赖、PHP 源码和 OPcache；独立 Nginx 镜像包含公开静态文件。 | PHP/Blade 在运行时执行，不需要像 Go/Java 那样编译为二进制。镜像构建仍需安装依赖、生成自动加载索引、做测试并固化代码版本；本题不需要代码混淆或注入。直接在运行目录解压代码会绕过镜像版本、依赖和测试的一致性，故发布的是完整不可变镜像。 |
| 清理、架构图、告警截图和公开仓库链接 | `terraform destroy` 按 workload → foundation → bootstrap 顺序执行；文档、图片和截图随交付物提交。 | 云资源的创建/清理可由 Terraform 完成；邮件确认、GitHub 注册、实际截图和最终提交仍需人工完成。state bucket 有防误删保护，备份 bucket 默认不强制清空。 |

## 当前 AWS 账号权限边界

已用本地 `AKSK.env` 做只读身份及 IAM policy 检查，账号在东京区域可用。账号限定自建角色名称为 `itv-*` 且必须附加 `InterviewCandidate-Boundary`。角色的有效权限还受该 boundary 约束。此账号没有授予 Step Functions (`states:*`) 和 SQS (`sqs:*`) 权限，所以本仓库的备份调度、结果检查和告警使用 Scheduler、Lambda、ECS、EventBridge、CloudWatch 与 SNS。CI 使用同一个受限 IAM 用户的 AK/SK；受用户现有权限约束。所有运行时 IAM 角色和服务关联角色由 `foundation` 预建。

`terraform plan` 只能验证配置和可读取的数据，不能证明每一次云端创建都会成功；部署后的任务、邮件订阅、日志和告警必须按 [验收清单](acceptance.md) 实测。配置均在仓库中落盘，但 AWS 凭证、真实 `terraform.tfvars`、state 和计划文件被 Git 忽略。

## 成本决策

本题选用单 AZ `db.t4g.micro`、20 GiB RDS 和最小 Linux Fargate 任务规格 `0.25 vCPU / 0.5 GiB`。无 RDS Multi-AZ、热备或 NAT Gateway。ALB 按服务要求使用两个 AZ 子网。RDS、ALB、Fargate、日志和存储仍会计费，演示结束后按运行手册清理。
