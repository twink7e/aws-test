variable "aws_region" {
  description = "AWS Region. Must equal the foundation state Region."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = var.aws_region == "ap-northeast-1"
    error_message = "This assessment must deploy in AWS Tokyo (ap-northeast-1)."
  }
}

variable "name_prefix" {
  description = "Prefix for workload resource names. Must match the foundation deployment."
  type        = string
  default     = "poper-test"
}

variable "foundation_state_bucket" {
  description = "S3 bucket containing the foundation Terraform state."
  type        = string
}

variable "foundation_state_key" {
  description = "S3 object key of the foundation Terraform state."
  type        = string
  default     = "poper-test/foundation.tfstate"
}

variable "app_image" {
  description = "Full ECR image reference for PHP-FPM, preferably immutable URI@sha256:digest."
  type        = string
}

variable "web_image" {
  description = "Full ECR image reference for Nginx, preferably immutable URI@sha256:digest."
  type        = string
}

variable "backup_image" {
  description = "Full ECR image reference for pg_dump backup, preferably immutable URI@sha256:digest."
  type        = string
}

variable "appconfig_agent_image" {
  description = "AWS AppConfig Agent image pinned to a multi-architecture manifest digest."
  type        = string
  default     = "public.ecr.aws/aws-appconfig/aws-appconfig-agent@sha256:58b8fd40f99ee2340d1a5a61f040e50010fb9b5efc3a9e5920268eefa18846b7"
}

variable "appconfig_poll_interval" {
  description = "How often the AppConfig Agent refreshes its local cache."
  type        = string
  default     = "45s"
}

variable "demo_message" {
  description = "Static demo message. Dynamic changes should use AppConfig instead."
  type        = string
  default     = "Hello from POPER test"
}

variable "enable_demo_failure_routes" {
  description = "Enable application routes for controlled HTTP 500 and ERROR alarm demonstrations."
  type        = bool
  default     = false
}

variable "app_url" {
  description = "Optional public application URL. Empty uses the foundation ALB URL."
  type        = string
  default     = ""
}

variable "web_task_cpu" {
  description = "CPU units for the combined web, app, and AppConfig Agent Fargate task."
  type        = number
  default     = 256
}

variable "web_task_memory" {
  description = "Memory in MiB for the combined web, app, and AppConfig Agent Fargate task."
  type        = number
  default     = 512
}

variable "ecs_scale_out_schedule_expression" {
  description = "Application Auto Scaling schedule for 2 ECS tasks, evaluated in Asia/Tokyo."
  type        = string
  default     = "cron(0 17 * * ? *)"
}

variable "ecs_scale_in_schedule_expression" {
  description = "Application Auto Scaling schedule for 1 ECS task, evaluated in Asia/Tokyo."
  type        = string
  default     = "cron(0 18 * * ? *)"
}

variable "backup_prefix" {
  description = "S3 key prefix used by the backup image."
  type        = string
  default     = "daily"
}

variable "backup_ephemeral_storage_gib" {
  description = "Optional Fargate scratch storage for pg_dump. Null uses the 20 GiB default; larger dumps need 21–200 GiB."
  type        = number
  default     = null

  validation {
    condition     = var.backup_ephemeral_storage_gib == null ? true : (var.backup_ephemeral_storage_gib >= 21 && var.backup_ephemeral_storage_gib <= 200)
    error_message = "backup_ephemeral_storage_gib must be null or between 21 and 200."
  }
}

variable "backup_schedule_expression" {
  description = "EventBridge Scheduler cron for daily pg_dump, evaluated in Asia/Tokyo."
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "backup_schedule_timezone" {
  description = "Time zone for the daily backup schedule."
  type        = string
  default     = "Asia/Tokyo"
}
