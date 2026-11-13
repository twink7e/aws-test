# 东京区域只读 Terraform 计划

检查日期：2026-11-13。使用本机 `AKSK.env` 对测评账号执行了只读身份、IAM policy、RDS 规格查询及 Terraform `plan`。没有执行 `terraform apply`，没有创建、修改或删除 AWS 资源。

| Stack | 检查结果 | 计划中的动作 |
| --- | --- | --- |
| `bootstrap` | `fmt`、`validate` 和实际东京账号 `plan` 通过。 | 创建 6 项 state S3 bucket 及其加密、版本化、公开访问阻止等配置；无修改或删除。 |
| `foundation` | `fmt`、`validate` 和实际东京账号 `plan` 通过。由于 state bucket 尚未创建，此次在临时目录移除了 backend 声明，用本地空 state 规划；仓库源文件未改动。 | 创建 87 项，包括 VPC/子网、ALB、单 AZ RDS、ECR、备份 S3、IAM、AppConfig、SNS、日志和告警；无修改或删除。 |
| `workload` | `fmt`、`validate` 通过；备份控制器 7 项本地测试通过。 | 需要 `foundation` 的真实远端 state 和三张 ECR 镜像 digest，现阶段无法做可信的云端 `plan`。 |

`foundation` 计划中 RDS 为 PostgreSQL 17.11、`db.t4g.micro`、20 GiB、`multi_az = false`、`publicly_accessible = false`，存储自动增长关闭。六个自建 IAM 角色均以 `itv-poper-test-` 开头并附加测评账号要求的 `InterviewCandidate-Boundary`；另有两个 AWS 服务关联角色。SNS 计划给 `minghe.yin+zhangsan@poper.co` 和 `te.qi+zhangsan@poper.co` 创建邮件订阅，部署后两位收件人仍须分别确认。

计划文件和真实变量文件保留在本机，均由 Git 忽略。`terraform plan` 证明配置能通过 provider 校验和当前可读 AWS 数据查询；AWS 创建权限、镜像启动、ALB 日志投递、邮件、调度和恢复仍须部署后验收。预计会持续计费的基础资源包括 RDS 和 ALB；应用 Fargate 平时运行一个最小任务，17:00–17:59 运行两个，备份任务仅执行时运行。评估完成后按 [运行手册](runbook.md) 销毁。
