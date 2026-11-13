resource "aws_ecs_cluster" "app" {
  name = "${var.project_name}-cluster"

  depends_on = [aws_iam_service_linked_role.ecs]

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name                 = "${local.iam_role_prefix}-task-execution"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume.json
  permissions_boundary = local.iam_permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "task_execution_base" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "random_id" "app_key" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "app_key" {
  name                    = "${var.project_name}/laravel-app-key"
  description             = "Laravel APP_KEY, injected into the ECS task at startup"
  recovery_window_in_days = 0 # Disposable interview environment; allows repeat creation.
}

resource "aws_secretsmanager_secret_version" "app_key" {
  secret_id     = aws_secretsmanager_secret.app_key.id
  secret_string = "base64:${random_id.app_key.b64_std}"
}

data "aws_iam_policy_document" "task_execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_db_instance.postgres.master_user_secret[0].secret_arn,
      aws_secretsmanager_secret.app_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name   = "${var.project_name}-task-secrets"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_secrets.json
}

resource "aws_iam_role" "app_task" {
  name                 = "${local.iam_role_prefix}-app-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume.json
  permissions_boundary = local.iam_permissions_boundary_arn
}

data "aws_iam_policy_document" "app_task" {
  statement {
    sid       = "StartAppConfigSession"
    actions   = ["appconfig:StartConfigurationSession"]
    resources = ["arn:${data.aws_partition.current.partition}:appconfig:${var.aws_region}:${local.account_id}:application/${aws_appconfig_application.app.id}/environment/${aws_appconfig_environment.app.environment_id}/configuration/${aws_appconfig_configuration_profile.runtime.configuration_profile_id}"]
  }

  statement {
    sid       = "PollAppConfigSession"
    actions   = ["appconfig:GetLatestConfiguration"]
    resources = ["arn:${data.aws_partition.current.partition}:appconfig:${var.aws_region}:${local.account_id}:application/${aws_appconfig_application.app.id}/environment/${aws_appconfig_environment.app.environment_id}/configuration/${aws_appconfig_configuration_profile.runtime.configuration_profile_id}"]
  }
}

resource "aws_iam_role_policy" "app_task" {
  name   = "${var.project_name}-appconfig-read"
  role   = aws_iam_role.app_task.id
  policy = data.aws_iam_policy_document.app_task.json
}

resource "aws_iam_role" "backup_task" {
  name                 = "${local.iam_role_prefix}-backup-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume.json
  permissions_boundary = local.iam_permissions_boundary_arn
}

data "aws_iam_policy_document" "backup_task" {
  statement {
    sid       = "ListBackupBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backup.arn]
  }

  statement {
    sid       = "WriteAndVerifyBackup"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.backup.arn}/*"]
  }

}

resource "aws_iam_role_policy" "backup_task" {
  name   = "${var.project_name}-backup-upload"
  role   = aws_iam_role.backup_task.id
  policy = data.aws_iam_policy_document.backup_task.json
}
