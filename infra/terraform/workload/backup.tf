# The image performs a full pg_dump, uploads it to S3, and verifies the object.
# Scheduler invokes a controller Lambda daily; the controller launches one ECS
# task and verifies the RunTask response. It also checks the task STOPPED event.
resource "aws_ecs_task_definition" "backup" {
  family                   = "${var.name_prefix}-backup"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = local.foundation.task_execution_role_arn
  task_role_arn            = local.foundation.backup_task_role_arn

  dynamic "ephemeral_storage" {
    for_each = var.backup_ephemeral_storage_gib == null ? [] : [var.backup_ephemeral_storage_gib]

    content {
      size_in_gib = ephemeral_storage.value
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "backup"
      image     = var.backup_image
      essential = true
      environment = [
        { name = "DB_HOST", value = local.foundation.db_endpoint },
        { name = "DB_PORT", value = tostring(local.foundation.db_port) },
        { name = "DB_NAME", value = local.foundation.db_name },
        { name = "DB_USERNAME", value = local.foundation.db_username },
        { name = "BACKUP_BUCKET", value = local.foundation.backup_bucket_name },
        { name = "BACKUP_PREFIX", value = var.backup_prefix },
        { name = "AWS_REGION", value = var.aws_region }
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${local.foundation.db_password_secret_arn}:password::" }
      ]
      ulimits = [
        { name = "nofile", softLimit = 131072, hardLimit = 131072 }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.awslogs_common, { "awslogs-group" = local.foundation.backup_log_group_name })
      }
    }
  ])
}

# A dedicated group isolates Scheduler launch metrics from other schedules.
resource "aws_scheduler_schedule_group" "backup" {
  name = "${var.name_prefix}-backup"
}

resource "aws_scheduler_schedule" "backup" {
  name                         = "${var.name_prefix}-daily-backup"
  group_name                   = aws_scheduler_schedule_group.backup.name
  schedule_expression          = var.backup_schedule_expression
  schedule_expression_timezone = var.backup_schedule_timezone
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.backup_controller.arn
    role_arn = local.foundation.backup_scheduler_role_arn
    input = jsonencode({
      action         = "launch"
      schedule_arn   = "<aws.scheduler.schedule-arn>"
      scheduled_time = "<aws.scheduler.scheduled-time>"
    })

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}

# Include all revisions in this backup family, including a task started
# manually for a restore drill or a task finishing during a CI deployment.
resource "aws_cloudwatch_event_rule" "backup_stopped" {
  name        = "${var.name_prefix}-backup-stopped"
  description = "Inspect the exit code of every stopped backup ECS task."

  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Task State Change"]
    detail = {
      clusterArn = [local.foundation.cluster_arn]
      group      = ["family:${var.name_prefix}-backup"]
      lastStatus = ["STOPPED"]
    }
  })
}

data "archive_file" "backup_controller" {
  type        = "zip"
  source_file = "${path.module}/backup_controller.py"
  output_path = "${path.module}/.terraform/backup_controller.zip"
}

resource "aws_lambda_function" "backup_controller" {
  function_name    = "${var.name_prefix}-backup-controller"
  description      = "Launch ECS backup task and inspect its STOPPED event."
  role             = local.foundation.backup_controller_lambda_role_arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "backup_controller.handler"
  filename         = data.archive_file.backup_controller.output_path
  source_code_hash = data.archive_file.backup_controller.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      ECS_CLUSTER_ARN            = local.foundation.cluster_arn
      BACKUP_TASK_DEFINITION_ARN = aws_ecs_task_definition.backup.arn
      BACKUP_TASK_GROUP          = "family:${var.name_prefix}-backup"
      BACKUP_SUBNET_IDS          = join(",", local.foundation.public_subnet_ids)
      BACKUP_SECURITY_GROUP_ID   = local.foundation.ecs_security_group_id
      SNS_TOPIC_ARN              = local.foundation.sns_topic_arn
      METRIC_NAMESPACE           = "${var.name_prefix}/Backup"
    }
  }
}

resource "aws_lambda_permission" "allow_backup_schedule" {
  statement_id  = "AllowBackupSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_controller.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.backup.arn
}

resource "aws_lambda_permission" "allow_backup_event" {
  statement_id  = "AllowBackupTaskStoppedEvent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_controller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_stopped.arn
}

resource "aws_cloudwatch_event_target" "backup_controller" {
  rule      = aws_cloudwatch_event_rule.backup_stopped.name
  target_id = "backup-controller"
  arn       = aws_lambda_function.backup_controller.arn

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 2
  }

  depends_on = [aws_lambda_permission.allow_backup_event]
}
