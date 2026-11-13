# Foundation delivers ALB access logs as JSON vended logs. Native
# HTTPCode_ELB_500_Count only counts ALB-originated responses, whereas the
# access-log elb_status_code also includes target-generated HTTP 500s.
resource "aws_cloudwatch_log_metric_filter" "alb_requests" {
  name           = "${var.name_prefix}-alb-requests"
  log_group_name = local.foundation.alb_log_group_name
  pattern        = "{ $.elb_status_code = * }"

  metric_transformation {
    name          = "ALBRequests"
    namespace     = "${var.name_prefix}/ALB"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_log_metric_filter" "alb_exact_500" {
  name           = "${var.name_prefix}-alb-exact-500"
  log_group_name = local.foundation.alb_log_group_name
  pattern        = "{ $.elb_status_code = \"500\" }"

  metric_transformation {
    name          = "ALBExact500"
    namespace     = "${var.name_prefix}/ALB"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_exact_500_ratio" {
  alarm_name          = "${var.name_prefix}-alb-exact-500-ratio"
  alarm_description   = "Exact HTTP 500 responses exceed 10% of ALB access-log requests in five minutes."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.foundation.sns_topic_arn]
  ok_actions          = [local.foundation.sns_topic_arn]

  metric_query {
    id          = "errors"
    return_data = false

    metric {
      metric_name = aws_cloudwatch_log_metric_filter.alb_exact_500.metric_transformation[0].name
      namespace   = aws_cloudwatch_log_metric_filter.alb_exact_500.metric_transformation[0].namespace
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "requests"
    return_data = false

    metric {
      metric_name = aws_cloudwatch_log_metric_filter.alb_requests.metric_transformation[0].name
      namespace   = aws_cloudwatch_log_metric_filter.alb_requests.metric_transformation[0].namespace
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "ratio"
    expression  = "IF(requests > 0, 100 * errors / requests, 0)"
    label       = "Exact HTTP 500 ratio (%)"
    return_data = true
  }
}

resource "aws_cloudwatch_metric_alarm" "backup_failed" {
  alarm_name          = "${var.name_prefix}-backup-failed"
  alarm_description   = "Backup controller reported a failed ECS launch or nonzero/missing container exit code."
  namespace           = "${var.name_prefix}/Backup"
  metric_name         = "BackupFailed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.foundation.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "backup_scheduler_target_error" {
  alarm_name          = "${var.name_prefix}-backup-scheduler-target-error"
  alarm_description   = "EventBridge Scheduler could not invoke the backup controller Lambda."
  namespace           = "AWS/Scheduler"
  metric_name         = "TargetErrorCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { ScheduleGroup = aws_scheduler_schedule_group.backup.name }
  alarm_actions       = [local.foundation.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "backup_scheduler_dropped" {
  alarm_name          = "${var.name_prefix}-backup-scheduler-dropped"
  alarm_description   = "EventBridge Scheduler exhausted retries and dropped a backup controller invocation."
  namespace           = "AWS/Scheduler"
  metric_name         = "InvocationDroppedCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { ScheduleGroup = aws_scheduler_schedule_group.backup.name }
  alarm_actions       = [local.foundation.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "backup_controller_lambda_error" {
  alarm_name          = "${var.name_prefix}-backup-controller-lambda-error"
  alarm_description   = "Backup controller Lambda failed to launch or inspect an ECS task."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.backup_controller.function_name }
  alarm_actions       = [local.foundation.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "backup_event_delivery_failed" {
  alarm_name          = "${var.name_prefix}-backup-event-delivery-failed"
  alarm_description   = "EventBridge permanently failed to deliver a backup STOPPED event to Lambda."
  namespace           = "AWS/Events"
  metric_name         = "FailedInvocations"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { RuleName = aws_cloudwatch_event_rule.backup_stopped.name }
  alarm_actions       = [local.foundation.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "no_healthy_web_targets" {
  alarm_name          = "${var.name_prefix}-no-healthy-web-targets"
  alarm_description   = "The ALB has no healthy web targets."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = local.foundation.alb_arn_suffix
    TargetGroup  = split(":", local.foundation.alb_target_group_arn)[5]
  }
  alarm_actions = [local.foundation.sns_topic_arn]
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.name_prefix}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS web tasks: running and desired"
          region = var.aws_region
          stat   = "Average"
          period = 60
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", local.foundation.cluster_name, "ServiceName", aws_ecs_service.web.name, { label = "Running" }],
            ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", local.foundation.cluster_name, "ServiceName", aws_ecs_service.web.name, { label = "Desired" }]
          ]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS web service CPU and memory (%)"
          region = var.aws_region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", local.foundation.cluster_name, "ServiceName", aws_ecs_service.web.name, { label = "CPU" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", local.foundation.cluster_name, "ServiceName", aws_ecs_service.web.name, { label = "Memory" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB target HTTP response classes"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "Target 2xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_3XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "Target 3xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "Target 4xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "Target 5xx" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB generated HTTP errors"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_3XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "ALB 3xx" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "ALB 4xx" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.foundation.alb_arn_suffix, { label = "ALB 5xx" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ALB access logs: exact HTTP 500 ratio"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            [{ expression = "IF(requests > 0, 100 * errors / requests, 0)", id = "ratio", label = "Exact HTTP 500 ratio (%)" }],
            ["${var.name_prefix}/ALB", "ALBExact500", { id = "errors", visible = false }],
            ["${var.name_prefix}/ALB", "ALBRequests", { id = "requests", visible = false }]
          ]
          annotations = { horizontal = [{ value = 10, label = "Alarm threshold" }] }
          yAxis       = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Backup task results and launch errors"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["${var.name_prefix}/Backup", "BackupSucceeded", { label = "Backup succeeded" }],
            ["${var.name_prefix}/Backup", "BackupFailed", { label = "Backup failed" }],
            ["AWS/Scheduler", "TargetErrorCount", "ScheduleGroup", aws_scheduler_schedule_group.backup.name, { label = "Scheduler target errors" }],
            ["AWS/Scheduler", "InvocationDroppedCount", "ScheduleGroup", aws_scheduler_schedule_group.backup.name, { label = "Scheduler dropped invocations" }]
          ]
        }
      }
    ]
  })
}
