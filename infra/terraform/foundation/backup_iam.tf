data "aws_iam_policy_document" "backup_scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:scheduler:${var.aws_region}:${local.account_id}:schedule-group/${var.project_name}-backup"]
    }
  }
}

resource "aws_iam_role" "backup_scheduler" {
  name                 = "${local.iam_role_prefix}-backup-scheduler"
  assume_role_policy   = data.aws_iam_policy_document.backup_scheduler_assume.json
  permissions_boundary = local.iam_permissions_boundary_arn
}

data "aws_iam_policy_document" "backup_scheduler" {
  statement {
    sid       = "InvokeBackupController"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${local.account_id}:function:${var.project_name}-backup-controller"]
  }
}

resource "aws_iam_role_policy" "backup_scheduler" {
  name   = "${var.project_name}-backup-scheduler"
  role   = aws_iam_role.backup_scheduler.id
  policy = data.aws_iam_policy_document.backup_scheduler.json
}

resource "aws_cloudwatch_log_group" "backup_controller" {
  name              = "/aws/lambda/${var.project_name}-backup-controller"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "backup_controller_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup_controller_lambda" {
  name                 = "${local.iam_role_prefix}-backup-controller"
  assume_role_policy   = data.aws_iam_policy_document.backup_controller_assume.json
  permissions_boundary = local.iam_permissions_boundary_arn
}

data "aws_iam_policy_document" "backup_controller_lambda" {
  statement {
    sid       = "WriteControllerLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.backup_controller.arn}:log-stream:*"]
  }

  statement {
    sid       = "RunBackupTask"
    actions   = ["ecs:RunTask"]
    resources = ["arn:${data.aws_partition.current.partition}:ecs:${var.aws_region}:${local.account_id}:task-definition/${var.project_name}-backup:*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.app.arn]
    }
  }

  statement {
    sid       = "PassBackupTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn, aws_iam_role.backup_task.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "NotifyBackupFailure"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid       = "PublishBackupMetric"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["${var.project_name}/Backup"]
    }
  }
}

resource "aws_iam_role_policy" "backup_controller_lambda" {
  name   = "${var.project_name}-backup-controller"
  role   = aws_iam_role.backup_controller_lambda.id
  policy = data.aws_iam_policy_document.backup_controller_lambda.json
}
