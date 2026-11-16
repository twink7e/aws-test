# 仓库资源清单

本表覆盖仓库中需要提交的目录和文件。Terraform 执行时生成的 `.terraform/`、`terraform.tfstate`、`terraform.tfvars`、`backend.hcl`、plan 文件，以及应用 `.env`、依赖和本地日志均不提交。`*.example` 是可公开的输入模板。

## 目录

| 目录 | 作用 |
| --- | --- |
| `/` | 仓库根目录，放总目标、通用规则和各交付物入口。 |
| `.github/` | GitHub 平台相关配置。 |
| `.github/workflows/` | GitHub Actions 工作流定义。 |
| `infra/` | 基础设施代码总入口。 |
| `infra/terraform/` | 全部 AWS Terraform stack；各 stack 独立 state。 |
| `infra/terraform/bootstrap/` | 在还没有远端 state 时创建 Terraform state bucket。 |
| `infra/terraform/foundation/` | 网络、数据库、负载均衡、镜像仓库、身份、配置、通知和日志基础资源。 |
| `infra/terraform/workload/` | 版本化容器任务、服务、扩缩容、备份工作流和运行告警。 |
| `app/` | Laravel 项目根目录，也是 PHP/Nginx 镜像的 Docker build context。 |
| `app/app/` | Laravel 业务类的 PSR-4 根目录。 |
| `app/app/Http/` | HTTP 请求处理层。 |
| `app/app/Http/Controllers/` | Laravel 控制器扩展位置；当前仅保留框架基类。 |
| `app/app/Http/Middleware/` | 请求日志等全局 HTTP 中间件。 |
| `app/app/Models/` | Eloquent 模型；示例用户模型保留框架骨架。 |
| `app/app/Providers/` | 应用服务注册入口。 |
| `app/app/Support/` | 与 AWS AppConfig Agent 通信的辅助类。 |
| `app/bootstrap/` | Laravel 启动、路由和中间件装配。 |
| `app/bootstrap/cache/` | Laravel 运行时生成的缓存目录；只提交占位 `.gitignore`。 |
| `app/config/` | Laravel 运行参数，均从环境变量读取。 |
| `app/database/` | 数据库迁移、示例工厂和 seed。 |
| `app/database/factories/` | Eloquent 测试数据工厂。 |
| `app/database/migrations/` | 可重复执行的数据库表结构迁移。 |
| `app/database/seeders/` | 可选示例数据入口。 |
| `app/docker/` | PHP-FPM、Nginx 运行配置、镜像定义与本地冒烟检查。 |
| `app/public/` | Web 根目录；仅此目录由 Nginx 对外提供静态文件。 |
| `app/resources/` | 未编译的应用呈现资源。 |
| `app/resources/views/` | Blade 视图。 |
| `app/routes/` | Web 与命令行路由。 |
| `app/storage/` | Laravel 可写运行时数据目录；内容不提交。 |
| `app/storage/app/` | 应用文件存储根目录。 |
| `app/storage/app/private/` | 私有应用文件目录。 |
| `app/storage/app/public/` | 可选公开应用文件目录。 |
| `app/storage/framework/` | 框架运行时文件根目录。 |
| `app/storage/framework/cache/` | 框架缓存。 |
| `app/storage/framework/cache/data/` | 数据缓存内容。 |
| `app/storage/framework/cache/locks/` | 缓存锁内容。 |
| `app/storage/framework/sessions/` | 文件 session 目录；部署默认使用内存 session。 |
| `app/storage/framework/testing/` | 本地测试临时文件。 |
| `app/storage/framework/views/` | Blade 编译后的缓存。 |
| `app/storage/logs/` | 本地日志占位；容器日志写 stdout/stderr 并由 ECS 收集。 |
| `app/tests/` | PHP 测试根目录。 |
| `app/tests/Feature/` | HTTP/业务行为测试。 |
| `app/tests/Unit/` | 纯 PHP 单元测试。 |
| `backup/` | 独立的 PostgreSQL 逻辑备份镜像和脚本。 |
| `docs/` | 架构、逐文件说明和操作手册。 |
| `scripts/` | 可以重建交付图片的辅助脚本。 |

## 根目录、文档和发布工作流文件

| 文件 | 作用 |
| --- | --- |
| `.editorconfig` | 缩进、换行等仓库级文本规范。 |
| `.gitignore` | 排除 Terraform state/变量、密钥、依赖、日志和 dump。 |
| `README.md` | 项目目标、完成标准、架构概览、所需输入和文档导航。 |
| `.github/workflows/release.yml` | `main` 推送和手工发布的 CI/CD：Secrets 中的 AWS AK/SK、测试、构建/推送镜像、Terraform 发布及 SNS 结果通知。 |
| `docs/acceptance.md` | 按测评要求逐项列出实现文件、已验证内容和剩余验收项。 |
| `docs/architecture.md` | Terraform stack 边界、网络、请求、配置、备份和日志流。 |
| `docs/architecture.png` | 可独立打开或提交的整体架构图。 |
| `docs/deployment-evidence.md` | 东京区域实际部署、访问、日志、告警、备份与恢复的验证记录及外部阻碍。 |
| `docs/evidence/cloudwatch-alarm-history.md` | 应用错误、ALB 精确 HTTP 500 比例和备份失败告警的 UTC 触发、SNS action 与恢复时间线。 |
| `docs/evidence/cloudwatch-application-error-history.png` | 东京区域 CloudWatch 应用 `ERROR` 告警 History 截图，记录状态变化与 SNS topic action。 |
| `docs/evidence/cloudwatch-alb-exact-500-ratio-history.png` | 东京区域 CloudWatch ALB 精确 HTTP 500 比例告警 History 截图，记录状态变化与 SNS topic action。 |
| `docs/evidence/cloudwatch-backup-failed-history.png` | 用户提供的东京区域 CloudWatch 备份失败告警 History 截图，记录告警触发、SNS topic action 和恢复。 |
| `docs/evidence/appconfig-rollback-2026-11-16.md` | 受控 AppConfig 渐进发布由真实应用错误告警触发自动回滚的时间线、EventBridge/SNS 观测、恢复发布及邮件验证边界。 |
| `docs/evidence/trace-correlation-2026-11-16.md` | `/healthz` 的自定义 Trace ID 在 CloudWatch Nginx 与 Laravel JSON 访问日志中关联的实测记录。 |
| `docs/evidence/scheduled-scaling-2026-11-16.md` | 东京时间正式 17:00 扩容及同日一次性双向扩缩容演练的 ECS、Application Auto Scaling、ALB 健康证据。 |
| `docs/terraform-feasibility.md` | 题目逐项的 Terraform 可实现性、告警设计、ECS/RDS 缩容限制和当前账号权限边界。 |
| `docs/plan-summary.md` | 东京账号 Terraform 部署进度、资源数量、关键配置与剩余验收条件。 |
| `docs/repository-map.md` | 当前逐目录、逐文件说明。 |
| `docs/runbook.md` | 首次部署、验收、备份恢复、告警演示和销毁步骤。 |
| `docs/submission.md` | 原题交付包索引：公开仓库、东京区域 AWS Console 入口、架构图、告警触发方法与三张告警 History 截图。 |
| `scripts/render_architecture.py` | 用 Pillow 重新生成 `docs/architecture.png`。 |

## Terraform bootstrap 文件

| 文件 | 作用 |
| --- | --- |
| `infra/terraform/bootstrap/.terraform.lock.hcl` | 固定已验证 AWS provider 版本及校验和。 |
| `infra/terraform/bootstrap/README.md` | state bucket 的首次创建与保护说明。 |
| `infra/terraform/bootstrap/versions.tf` | Terraform/provider 约束和区域配置。 |
| `infra/terraform/bootstrap/variables.tf` | 区域及资源名前缀输入。 |
| `infra/terraform/bootstrap/main.tf` | state S3 bucket、加密、版本化、公共访问阻止、TLS 策略及防误删配置。 |
| `infra/terraform/bootstrap/outputs.tf` | 输出 state bucket 名供另外两个 stack 使用。 |
| `infra/terraform/bootstrap/terraform.tfvars.example` | 可复制的 bootstrap 输入样例。 |

## Terraform foundation 文件

| 文件 | 作用 |
| --- | --- |
| `infra/terraform/foundation/.terraform.lock.hcl` | 固定 AWS/random provider 版本及校验和。 |
| `infra/terraform/foundation/README.md` | foundation 输入、输出、资源和部署顺序说明。 |
| `infra/terraform/foundation/versions.tf` | Terraform/provider 约束、S3 backend 和通用 AWS 标签。 |
| `infra/terraform/foundation/variables.tf` | 区域、网络、数据库、通知、AppConfig 等输入。 |
| `infra/terraform/foundation/data.tf` | AWS 账号、分区、RDS 引擎版本等数据源及命名约定。 |
| `infra/terraform/foundation/network.tf` | VPC、公有/私有子网、路由、安全组规则。 |
| `infra/terraform/foundation/alb.tf` | ALB、目标组、健康检查、HTTP 与可选 HTTPS listener。 |
| `infra/terraform/foundation/database.tf` | 私有 RDS PostgreSQL、子网组及托管主密码。 |
| `infra/terraform/foundation/storage.tf` | 备份 S3 bucket、保留期、ECR 三个仓库及镜像清理策略。 |
| `infra/terraform/foundation/ecs_iam.tf` | ECS cluster、任务执行角色、应用/备份任务角色、APP_KEY Secret 与最小权限。 |
| `infra/terraform/foundation/backup_iam.tf` | 备份 Scheduler、Lambda 控制器的受限角色及控制器日志组。 |
| `infra/terraform/foundation/service_linked_roles.tf` | ECS 与 Application Auto Scaling 所需的 AWS 服务关联角色。 |
| `infra/terraform/foundation/appconfig.tf` | AppConfig 应用、环境、托管 JSON 版本、部署策略、告警监控及部署事件通知。 |
| `infra/terraform/foundation/notifications.tf` | SNS topic、邮件订阅及 EventBridge/CloudWatch 发布策略。 |
| `infra/terraform/foundation/observability.tf` | 基础日志组、ALB 访问日志投递、应用 ERROR 指标与 AppConfig 回滚告警。 |
| `infra/terraform/foundation/outputs.tf` | ALB、ECS、RDS、S3、ECR、IAM、AppConfig 和日志组的跨 stack 输出。 |
| `infra/terraform/foundation/backend.hcl.example` | foundation 远端 state bucket/key 模板。 |
| `infra/terraform/foundation/terraform.tfvars.example` | 可公开的资源参数与收件人占位样例。 |

## Terraform workload 文件

| 文件 | 作用 |
| --- | --- |
| `infra/terraform/workload/.terraform.lock.hcl` | 固定 AWS provider 版本及校验和。 |
| `infra/terraform/workload/README.md` | 工作负载运行行为、验收点和 AWS 文档链接。 |
| `infra/terraform/workload/versions.tf` | Terraform/provider 约束、S3 backend 和标签。 |
| `infra/terraform/workload/variables.tf` | 镜像 digest、state 位置、任务资源、演示开关、备份时区等输入。 |
| `infra/terraform/workload/data.tf` | 读取 foundation state 输出并组装 URL、日志等公共值。 |
| `infra/terraform/workload/ecs.tf` | PHP-FPM/Nginx/AppConfig Agent 同任务定义及 ECS service。 |
| `infra/terraform/workload/autoscaling.tf` | 东京时间 17:00 扩到 2、18:00 缩到 1 的定时操作。 |
| `infra/terraform/workload/backup.tf` | 备份 ECS 任务、Scheduler、Lambda 控制器及 ECS 停止事件规则。 |
| `infra/terraform/workload/backup_controller.py` | 检查 ECS 启动响应与任务退出码，并发布备份指标和失败通知。 |
| `infra/terraform/workload/test_backup_controller.py` | 本地验证控制器的正常启动、HTTP 200 但含 `Failures`、任务失败等路径。 |
| `infra/terraform/workload/monitoring.tf` | ALB 精确 500 比例、备份/健康告警和 CloudWatch 看板。 |
| `infra/terraform/workload/outputs.tf` | 服务 URL、任务、备份工作流、看板与关键告警标识。 |
| `infra/terraform/workload/backend.hcl.example` | workload 独立远端 state key 模板。 |
| `infra/terraform/workload/terraform.tfvars.example` | 三个 ECR 镜像 digest 和运行参数的样例。 |

## Laravel 根目录和业务文件

| 文件 | 作用 |
| --- | --- |
| `app/.dockerignore` | 缩小构建上下文并排除 `.env`、测试产物和本地依赖。 |
| `app/.editorconfig` | Laravel 项目内的文本格式约定。 |
| `app/.env.example` | 本地 Laravel 环境变量示例；真实 `.env` 不入库。 |
| `app/.gitattributes` | Git 对生成文件和文本文件的属性约定。 |
| `app/.gitignore` | Laravel 本地依赖、缓存、日志和密钥的忽略规则。 |
| `app/Dockerfile` | PHP 8.4 FPM 多阶段镜像；Composer 安装生产依赖，复制 PHP 源码并启用 OPcache。 |
| `app/README.md` | Laravel 示例应用的本地运行、镜像构建及日志/配置行为说明。 |
| `app/artisan` | Laravel 命令行入口。 |
| `app/composer.json` | PHP 包、自动加载及框架脚本定义。 |
| `app/composer.lock` | 固定可复现的 Laravel/PHP 依赖版本。 |
| `app/phpunit.xml` | PHP 测试环境和测试套件设置。 |
| `app/app/Http/Controllers/Controller.php` | Laravel 控制器基类。 |
| `app/app/Http/Middleware/AccessLog.php` | 为每个请求写 JSON 日志，包含路径、状态、耗时和 Trace ID。 |
| `app/app/Models/User.php` | 框架示例用户模型，供默认迁移和测试使用。 |
| `app/app/Providers/AppServiceProvider.php` | 应用服务注册与启动钩子。 |
| `app/app/Support/AppConfig.php` | 从本任务内 AppConfig Agent 读取动态首页配置。 |
| `app/bootstrap/app.php` | Laravel 路由、异常响应和访问日志中间件装配。 |
| `app/bootstrap/cache/.gitignore` | 保留可写缓存目录，但排除生成的缓存文件。 |
| `app/bootstrap/providers.php` | 框架 provider 列表。 |

## Laravel 配置、数据库与容器文件

| 文件 | 作用 |
| --- | --- |
| `app/config/app.php` | 应用名、环境、密钥、时区等基础设置。 |
| `app/config/auth.php` | 认证 guard/provider 的默认配置。 |
| `app/config/cache.php` | 缓存驱动；容器默认使用内存数组。 |
| `app/config/database.php` | PostgreSQL 连接与其他框架默认数据库连接配置。 |
| `app/config/demo.php` | 首页演示变量、AppConfig URL 和受控故障路由开关。 |
| `app/config/filesystems.php` | Laravel 文件系统磁盘配置。 |
| `app/config/logging.php` | 应用/访问 JSON 日志写入 stderr，供 ECS awslogs 收集。 |
| `app/config/mail.php` | Laravel 邮件驱动默认值；告警实际由 AWS SNS 发出。 |
| `app/config/queue.php` | 队列驱动；演示部署默认同步执行。 |
| `app/config/services.php` | 外部服务凭证读取入口。 |
| `app/config/session.php` | Session 驱动设置；演示部署默认数组模式。 |
| `app/database/.gitignore` | 不提交本地 SQLite 数据库文件。 |
| `app/database/factories/UserFactory.php` | 测试用用户数据工厂。 |
| `app/database/migrations/0001_01_01_000000_create_users_table.php` | 默认用户表迁移。 |
| `app/database/migrations/0001_01_01_000001_create_cache_table.php` | 默认数据库缓存表迁移。 |
| `app/database/migrations/0001_01_01_000002_create_jobs_table.php` | 默认数据库队列表迁移。 |
| `app/database/seeders/DatabaseSeeder.php` | 默认 seed 入口。 |
| `app/docker/fpm.conf` | PHP-FPM 进程池、监听端口和日志输出。 |
| `app/docker/nginx.Dockerfile` | 独立 Nginx 镜像，包含公开静态资源。 |
| `app/docker/nginx.conf` | FastCGI 代理、JSON 访问日志和 8080 非 root 监听。 |
| `app/docker/php.ini` | PHP 运行配置及 OPcache/错误日志设置。 |
| `app/docker/smoke.sh` | 本地容器启动及 HTTP 冒烟检查脚本。 |

## Laravel 静态资源、运行目录和测试文件

| 文件 | 作用 |
| --- | --- |
| `app/public/.htaccess` | Apache 环境的 Laravel 重写规则；ECS 实际使用 Nginx。 |
| `app/public/favicon.ico` | 默认站点图标。 |
| `app/public/index.php` | HTTP 请求进入 Laravel 的 front controller。 |
| `app/public/robots.txt` | 搜索引擎爬取提示。 |
| `app/resources/views/home.blade.php` | 展示非敏感环境变量和 AppConfig 动态值的首页。 |
| `app/routes/console.php` | Laravel 命令行路由。 |
| `app/routes/web.php` | 首页、健康检查和可选告警演示路由。 |
| `app/storage/app/.gitignore` | 只保留应用文件目录，不提交内容。 |
| `app/storage/app/private/.gitignore` | 只保留私有文件目录，不提交内容。 |
| `app/storage/app/public/.gitignore` | 只保留公开文件目录，不提交内容。 |
| `app/storage/framework/.gitignore` | 只保留框架运行目录，不提交内容。 |
| `app/storage/framework/cache/.gitignore` | 只保留框架缓存目录，不提交内容。 |
| `app/storage/framework/cache/data/.gitignore` | 只保留数据缓存目录，不提交内容。 |
| `app/storage/framework/cache/locks/.gitignore` | 只保留缓存锁目录，不提交内容。 |
| `app/storage/framework/sessions/.gitignore` | 只保留文件 session 目录，不提交内容。 |
| `app/storage/framework/testing/.gitignore` | 只保留测试临时目录，不提交内容。 |
| `app/storage/framework/views/.gitignore` | 只保留 Blade 编译缓存目录，不提交内容。 |
| `app/storage/logs/.gitignore` | 只保留本地日志目录，不提交内容。 |
| `app/tests/TestCase.php` | Laravel 测试基类。 |
| `app/tests/Feature/ExampleTest.php` | Laravel 默认首页 HTTP 状态测试。 |
| `app/tests/Unit/ExampleTest.php` | 纯 PHP 单元测试示例。 |

## 备份文件

| 文件 | 作用 |
| --- | --- |
| `backup/.dockerignore` | 排除备份构建上下文中的本地文件。 |
| `backup/Dockerfile` | PostgreSQL 客户端和 S3 SDK 的 ARM64 备份镜像。 |
| `backup/README.md` | 备份镜像参数、上传校验及恢复说明。 |
| `backup/run-backup` | 执行 `pg_dump -Fc`、检测非空文件并调用上传程序。 |
| `backup/upload.py` | 以 ECS task role 上传 S3 并核对对象长度。 |
