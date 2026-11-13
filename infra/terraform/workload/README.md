# Workload Terraform stack

This stack runs the Laravel demonstration application and daily PostgreSQL
backup in the AWS resources created by `../foundation`. The foundation stack
must exist first. All workloads use Fargate in `ap-northeast-1` by default.

## Files

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform/provider versions, S3 backend, AWS provider and common tags. |
| `variables.tf` | Deployment parameters, image references, schedule, demo switches. |
| `data.tf` | Read foundation S3 state and construct shared endpoints. |
| `ecs.tf` | Three-container Laravel/Nginx/AppConfig Agent task and ECS service with ALB and rollback. |
| `autoscaling.tf` | Time zone aware ECS scheduled scaling: 2 tasks at 17:00, 1 at 18:00. |
| `backup.tf` | pg_dump ECS task, daily Scheduler target, stopped-task EventBridge rule and Lambda controller. |
| `backup_controller.py` | Starts ECS tasks, checks `RunTask.Failures`, inspects stop events, publishes metrics and SNS failures. |
| `test_backup_controller.py` | Local tests for successful launch, HTTP 200 with failures, missing tasks, and exit-code results. |
| `monitoring.tf` | Exact HTTP 500 ratio, backup/availability alarms, CloudWatch dashboard. |
| `outputs.tf` | Service, task, workflow, dashboard and alarm references. |
| `backend.hcl.example` | Example S3 backend configuration for this stack's state. |
| `terraform.tfvars.example` | Example deployment inputs. Copy locally; do not commit real values. |

## Deploy

Supply the backend bucket and immutable app, web, and backup image references
after applying `../foundation` and pushing the first images:

```sh
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

The S3 backend key for this stack is `poper-test/workload.tfstate`. Its
`foundation_state_bucket` input must point to the bucket holding
`poper-test/foundation.tfstate`. The release workflow can pass the three image
references as `TF_VAR_app_image`, `TF_VAR_web_image`, and
`TF_VAR_backup_image`, plus `TF_VAR_foundation_state_bucket`.

## Runtime behavior

The web task contains Nginx on port 8080, PHP-FPM on port 9000, and the AWS
AppConfig Agent on port 2772. Nginx and PHP-FPM share one Fargate task network
namespace. The ALB health check uses `/healthz`; app code fetches AppConfig
from the local agent on each request, so configuration updates do not require
a new image or service deployment. Nginx, PHP-FPM, AppConfig Agent, and the
backup container each have a `nofile` soft/hard limit of 131072. Both task
definitions default to Fargate's smallest Linux size (256 CPU units / 512 MiB).
The PHP-FPM pool allows at most two workers to stay within the web task's
memory budget; increase `web_task_cpu` and `web_task_memory` together if live
metrics show pressure.
The Agent image is pinned to a manifest digest verified to include ARM64 and
AMD64 variants; update the digest deliberately when upgrading Agent.

Application Auto Scaling changes both minimum and maximum task capacity to 2
at 17:00 and back to 1 at 18:00 in `Asia/Tokyo`. `desired_count` is ignored by
Terraform after initial service creation because Auto Scaling owns it. The
scalable target's minimum and maximum capacity are also ignored after creation:
scheduled actions own those bounds, so a CI apply during 17:00–17:59 cannot
reset the target to 1 task. When changing an existing schedule, inspect both
actions' current capacity state.
On first creation, Terraform seeds the current Tokyo hour's desired capacity,
including 2 if the initial plan is made during 17:00–17:59.

EventBridge Scheduler invokes the backup controller Lambda at 02:00 Tokyo
time. The controller calls ECS `RunTask` with a stable client token for
retries. It rejects a nonempty `Failures` list or missing task even when the
API returned HTTP 200. An EventBridge rule sends each stopped backup task back
to the same controller. The controller treats nonzero or missing container
exit codes and task start failures as backup failures, publishes
`BackupFailed` to CloudWatch, and sends an SNS notification. It publishes
`BackupSucceeded` when the dump exits 0. A dedicated Scheduler group isolates
its `TargetErrorCount` and `InvocationDroppedCount` metrics. CloudWatch also
alarms on controller Lambda errors and permanent EventBridge delivery
failures. The foundation stack owns the Scheduler and Lambda IAM roles and
the controller log group's retention. The backup image uploads the dump and
verifies the S3 object. Invoke the controller with a test `launch` payload to
verify the complete path before relying on the daily schedule.
The backup image writes a temporary dump to Fargate scratch storage. The
default is 20 GiB; set `backup_ephemeral_storage_gib` to 21–200 if the dump
cannot fit. A dump larger than 200 GiB needs a streaming upload that does not
stage the whole archive on Fargate.

The foundation stack creates CloudWatch log groups, retention, JSON ALB access
log delivery, and the application `ERROR` alarm used as an AppConfig rollback
monitor. This stack creates ALB access-log metric filters for *all requests*
and *exact HTTP 500s* using `elb_status_code`, then alarms when the five-minute
ratio exceeds 10%. The native `HTTPCode_ELB_500_Count` metric covers only
load-balancer-originated responses and would miss Laravel 500s. Log delivery is
batched, so this alarm has more delay than a native ALB metric. CloudWatch Logs
metric filters may count duplicate delivered log records, as AWS documents.

The dashboard includes running/desired ECS tasks, CPU, memory, ALB target
response classes, ALB-generated error classes, exact 500 ratio, and backup
success/failure and Scheduler launch metrics. The `enable_demo_failure_routes`
switch defaults to false;
turn it on temporarily only when demonstrating the alerts.

No SQS dead-letter queue or Step Functions state machine is created because
this account's permission boundary denies those services. Scheduler launch
errors, ECS `RunTask` failures, stopped task events and controller errors are
monitored separately. EventBridge and Lambda can deliver an event more than
once; the ECS client token prevents duplicate task launches for the same
scheduled time, but repeated failures may produce duplicate alerts.

## AWS references

- [ECS Fargate task definitions and `nofile`](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [AWS AppConfig Agent for ECS](https://docs.aws.amazon.com/appconfig/latest/userguide/appconfig-integration-containers-agent.html)
- [ECS task state change events](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html)
- [ALB access logs in CloudWatch Logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-logs.html)
- [EventBridge Scheduler metrics](https://docs.aws.amazon.com/scheduler/latest/UserGuide/monitoring-cloudwatch.html)
