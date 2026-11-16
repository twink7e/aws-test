resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/app"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/${var.project_name}/web"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "agent" {
  name              = "/${var.project_name}/appconfig-agent"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "backup" {
  name              = "/${var.project_name}/backup"
  retention_in_days = var.log_retention_days
}

# ECS Container Insights writes embedded performance metrics to this group.
# Pre-create it so AWS does not leave an automatically created group without
# a retention policy when the first Fargate task starts.
resource "aws_cloudwatch_log_group" "container_insights_performance" {
  name              = "/aws/ecs/containerinsights/${var.project_name}-cluster/performance"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "alb_access" {
  name              = "/aws/vendedlogs/elasticloadbalancing/${var.project_name}/access"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "rds_postgresql" {
  name              = "/aws/rds/instance/${local.db_identifier}/postgresql"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "rds_upgrade" {
  name              = "/aws/rds/instance/${local.db_identifier}/upgrade"
  retention_in_days = var.log_retention_days
}

# CloudWatch Logs vended delivery is the direct ALB -> CloudWatch Logs path. The
# ALB's legacy access_logs block only supports S3 and is intentionally unused.
resource "aws_cloudwatch_log_delivery_source" "alb_access" {
  name         = "${var.project_name}-alb-access"
  log_type     = "ALB_ACCESS_LOGS"
  resource_arn = aws_lb.app.arn
}

resource "aws_cloudwatch_log_delivery_destination" "alb_access" {
  name          = "${var.project_name}-alb-access"
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.alb_access.arn
  }
}

data "aws_iam_policy_document" "alb_log_delivery" {
  statement {
    sid    = "AllowVendedALBLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.alb_access.arn}:log-stream:*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_log_delivery_source.alb_access.arn]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "alb_log_delivery" {
  policy_name     = "${var.project_name}-alb-log-delivery"
  policy_document = data.aws_iam_policy_document.alb_log_delivery.json
}

resource "aws_cloudwatch_log_delivery" "alb_access" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.alb_access.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.alb_access.arn

  depends_on = [aws_cloudwatch_log_resource_policy.alb_log_delivery]
}

# Laravel's Monolog JsonFormatter emits `level_name: "ERROR"` on stderr.
resource "aws_cloudwatch_log_metric_filter" "app_error" {
  name           = "${var.project_name}-app-error"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "{ $.level_name = \"ERROR\" }"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "${var.project_name}/Application"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "app_error" {
  alarm_name          = "${var.project_name}-application-error"
  alarm_description   = "Laravel emitted one or more ERROR log events in one minute; also used as AppConfig rollback guard."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  namespace           = "${var.project_name}/Application"
  metric_name         = "ApplicationErrors"
  statistic           = "Sum"
  period              = 60
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.app_error]
}
