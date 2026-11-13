# AWS foundation Terraform stack

This stack creates the reusable AWS base for the POPER interview test in Tokyo (`ap-northeast-1`): network, public ALB, private PostgreSQL, ECS cluster, image registries, backup bucket, IAM, Secrets Manager, AppConfig, CloudWatch logs, and email notifications. The separate `../workload` stack deploys the three containers, scheduled scaling, backup workflow, and operational dashboard.

## File map

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform/provider versions, S3 backend declaration, AWS default tags. |
| `variables.tf` | All configurable inputs and their defaults. |
| `data.tf` | Account/partition data, latest PostgreSQL 17 minor version, shared names. |
| `network.tf` | VPC, two public and two isolated DB subnets, routes and security groups. |
| `alb.tf` | Internet-facing ALB, `/healthz` target group, HTTP/optional HTTPS listeners. |
| `database.tf` | Single-AZ PostgreSQL 17 with RDS-managed password secret. |
| `storage.tf` | Encrypted backup S3 bucket, retention, ECR app/web/backup repositories. |
| `observability.tf` | CloudWatch log groups, direct JSON ALB log delivery, Laravel ERROR alarm. |
| `notifications.tf` | SNS topic, email subscriptions and resource policy. |
| `appconfig.tf` | Hosted runtime JSON, rollback monitor, deployment strategies, EventBridge completion/rollback notifications. |
| `ecs_iam.tf` | ECS cluster and least-privilege task roles; generated Laravel APP_KEY. |
| `backup_iam.tf` | Foundation-owned Scheduler and Lambda backup controller roles, plus the controller log group. |
| `service_linked_roles.tf` | AWS-managed ECS and ECS Application Auto Scaling service-linked roles. |
| `outputs.tf` | Stable cross-stack identifiers and CI values. |
| `backend.hcl.example` | Safe S3 backend example. Copy to ignored `backend.hcl`. |
| `terraform.tfvars.example` | Safe input example. Copy to ignored `terraform.tfvars`. |

## Apply order and inputs

1. Apply `../bootstrap`, then copy its `state_bucket_name` into this directory's `backend.hcl`. The backend key is `poper-test/foundation.tfstate` by default.
2. Set two real email addresses in `alert_email_addresses`. SNS sends each a confirmation email; neither address receives alerts until confirmed. An empty set is valid while preparing the stack.
3. If HTTPS is required, provide a Tokyo ACM certificate ARN in `acm_certificate_arn` and point your DNS name to the ALB. Without a certificate, the example serves HTTP on the ALB DNS name.
4. Run the plan and apply with an AWS identity permitted to create the foundation resources. **No AWS resources are created by repository checkout or local validation.**

The interview account only permits custom IAM roles named `itv-*` when they carry the `InterviewCandidate-Boundary` permissions boundary. Every custom role in this stack uses `itv-${project_name}-...` and the boundary ARN constructed from the current account ID. The two AWS-managed service-linked roles are exempt from that custom-role naming rule; they use an untagged provider because the candidate cannot tag roles outside `itv-*`. They must not already exist when Terraform first creates them; if they do, import them into this stack instead of attempting a duplicate create.

```sh
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
# Replace the example AWS account ID and set the real email inputs.
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

The release workflow uses the existing interview candidate IAM user's access key and secret key from the local `AKSK.env` file. Put their values in the new test repository's **GitHub Actions Secrets** as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`; never commit `AKSK.env` or the keys. Set repository variables `TF_STATE_BUCKET`, `AWS_REGION`, and `SNS_TOPIC_ARN` from the bootstrap/foundation outputs. The candidate user already has the `InterviewCandidate-Services` and `InterviewCandidate-IAM` identity policies that authorize image pushes, Terraform workload deployment, and notifications. Foundation creates no separate GitHub identity. Use this dedicated short-lived interview account only for the test and remove the Actions secrets when finished.

## AppConfig release procedure

The initial hosted JSON is in `appconfig_initial_content` and is deployed immediately during bootstrap, before the ECS service exists. The AppConfig Agent sidecar later polls it; Laravel reads `homepage_message` through `localhost:2772` on each request. The AppConfig environment monitors the Laravel `level_name = ERROR` CloudWatch alarm. When that alarm fires during a gradual deployment or its final bake period, AppConfig rolls back to the previous version. The monitoring window does not cover failures after completion.

Before the **next** JSON change, set `appconfig_use_gradual_deployment = true` in `terraform.tfvars`, then edit `appconfig_initial_content` and run `terraform plan`/`terraform apply` in this directory. This uses the five-minute gradual strategy plus a five-minute final bake. Changing the switch alone also creates a deployment of the current version, so it is safe to do as a separate apply before editing the JSON. Leaving the switch false causes further changes to deploy immediately; review the plan before applying. This variable is the Terraform-managed release path for configuration changes. The output `appconfig_gradual_strategy_id` also identifies the strategy if a future release pipeline uses the AppConfig API.

The AWS-authored EventBridge extension association emits deployment completion and rollback events. EventBridge rules match this environment's extension association ARN and publish them to SNS. The rules use the association ARN because deployment events may omit application/environment display names. Event delivery is [best effort](https://docs.aws.amazon.com/eventbridge/latest/ref/events-ref-appconfig.html), so verify deployment state in AppConfig for authoritative release status. Email subscriptions must be confirmed. The initial deployment explicitly waits for the extension association and SNS event targets, so its completion event has a configured path.

## Cost, network and lifecycle limits

Two public subnets host both ALB and Fargate tasks. Fargate receives a public IP so it can pull ECR images and reach CloudWatch/AppConfig without NAT or VPC endpoints. Its security group accepts inbound port 8080 **only from the ALB security group**; a public IP alone does not open direct access. Tasks can make outbound internet requests, and this cost-saving arrangement has a larger public-network exposure than private-subnet tasks with NAT/endpoints. The two DB subnets have no default route, RDS has no public endpoint, and only the ECS security group may connect to PostgreSQL port 5432. If stronger isolation is needed, move Fargate to private subnets and add NAT or the required VPC endpoints; expect extra recurring cost.

The baseline is one single-AZ `db.t4g.micro` PostgreSQL instance, 20 GiB gp3, seven-day application/ALB/RDS log retention, and seven-day pg_dump object expiry. The web task is 0.25 vCPU / 0.5 GiB and usually has one replica; the backup task is 0.25 vCPU / 0.5 GiB and runs only on schedule. PHP-FPM is capped at two workers to fit the small task. This short-lived assessment deliberately omits RDS Multi-AZ, a standby database, and production-grade cross-AZ failover to control cost. The ALB still needs two AZ subnets, but that network requirement does not turn RDS into a Multi-AZ deployment. Container Insights, ALB, RDS, AppConfig requests, logs, ECR storage and SNS may all incur charges. Scheduled Fargate scaling down is owned by `../workload` and can return from two tasks to one; **RDS allocated storage can only grow, not shrink in place**. `db_max_allocated_storage_gib = null` disables RDS storage autoscaling by default. A smaller database volume requires a new RDS instance and data migration/restore. The S3 backup bucket has versioning and is not force-destroyed by default; set `force_destroy_backup_bucket = true` only when intentionally removing its objects during teardown. ECR test repositories allow forced deletion. The state bucket has a separate `prevent_destroy` guard.

RDS creates the master password in Secrets Manager, and Terraform stores only its secret ARN. Laravel `APP_KEY` is generated by Terraform and stored in Secrets Manager, but its generated value **also resides in encrypted remote Terraform state**. Restrict state read access to the candidate user and trusted operators. ECS task execution can read both secrets at startup; the application task role can poll only this AppConfig configuration, and the backup task role can write/read S3 backup objects. CloudWatch's ALB log delivery uses [vended logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-logs.html) with JSON output, including `elb_status_code`; it is distinct from legacy S3 ALB logging.

The foundation stack also creates the backup Scheduler execution role and Lambda controller role. Scheduler can invoke only the `${project_name}-backup-controller` Lambda. The controller can run only the `${project_name}-backup` ECS task definition family in this cluster and pass its two task roles; it can also write to its precreated log group, publish to the alerts topic, and emit metrics under `${project_name}/Backup`. The workload stack creates the actual schedule, controller function, ECS task-state event rule, and alarms. The controller checks the `RunTask` API response for a nonempty `Failures` list or no task, because ECS can return HTTP 200 with launch failures and no later STOPPED event. The same controller handles STOPPED events and checks container exit status. No workload IAM role creation is needed.
