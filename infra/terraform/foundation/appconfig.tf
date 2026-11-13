resource "aws_appconfig_application" "app" {
  name        = var.project_name
  description = "Dynamic Laravel homepage configuration"
}

data "aws_iam_policy_document" "appconfig_monitor_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["appconfig.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "appconfig_monitor" {
  name                 = "${local.iam_role_prefix}-appconfig-monitor"
  assume_role_policy   = data.aws_iam_policy_document.appconfig_monitor_assume.json
  permissions_boundary = local.iam_permissions_boundary_arn
}

data "aws_iam_policy_document" "appconfig_monitor" {
  statement {
    actions   = ["cloudwatch:DescribeAlarms"]
    resources = ["*"] # DescribeAlarms does not support resource-level IAM permissions.
  }
}

resource "aws_iam_role_policy" "appconfig_monitor" {
  name   = "${var.project_name}-appconfig-monitor"
  role   = aws_iam_role.appconfig_monitor.id
  policy = data.aws_iam_policy_document.appconfig_monitor.json
}

resource "aws_appconfig_environment" "app" {
  application_id = aws_appconfig_application.app.id
  name           = var.environment

  monitor {
    alarm_arn      = aws_cloudwatch_metric_alarm.app_error.arn
    alarm_role_arn = aws_iam_role.appconfig_monitor.arn
  }

  depends_on = [aws_iam_role_policy.appconfig_monitor]
}

resource "aws_appconfig_configuration_profile" "runtime" {
  application_id = aws_appconfig_application.app.id
  name           = "runtime"
  location_uri   = "hosted"
  type           = "AWS.Freeform"
  description    = "Non-secret runtime JSON, polled by the ECS AppConfig agent sidecar"
}

resource "aws_appconfig_hosted_configuration_version" "initial" {
  application_id           = aws_appconfig_application.app.id
  configuration_profile_id = aws_appconfig_configuration_profile.runtime.configuration_profile_id
  content_type             = "application/json"
  content                  = var.appconfig_initial_content
  description              = "Initial runtime configuration"
}

# The first deployment must succeed before ECS exists and before the monitor has
# traffic. Future changes should use the gradual strategy below.
resource "aws_appconfig_deployment_strategy" "initial" {
  name                           = "${var.project_name}-initial"
  description                    = "Immediate bootstrap deployment"
  deployment_duration_in_minutes = 0
  final_bake_time_in_minutes     = 0
  growth_factor                  = 100
  growth_type                    = "LINEAR"
  replicate_to                   = "NONE"
}

resource "aws_appconfig_deployment_strategy" "gradual" {
  name                           = "${var.project_name}-gradual"
  description                    = "Five-minute rollout and five-minute alarm bake for later updates"
  deployment_duration_in_minutes = 5
  final_bake_time_in_minutes     = 5
  growth_factor                  = 20
  growth_type                    = "LINEAR"
  replicate_to                   = "NONE"
}

resource "aws_appconfig_deployment" "initial" {
  application_id           = aws_appconfig_application.app.id
  configuration_profile_id = aws_appconfig_configuration_profile.runtime.configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.initial.version_number
  deployment_strategy_id   = var.appconfig_use_gradual_deployment ? aws_appconfig_deployment_strategy.gradual.id : aws_appconfig_deployment_strategy.initial.id
  environment_id           = aws_appconfig_environment.app.environment_id
  description              = var.appconfig_use_gradual_deployment ? "Gradual monitored runtime configuration deployment" : "Bootstrap runtime configuration deployment"

  depends_on = [
    aws_appconfig_extension_association.eventbridge,
    aws_cloudwatch_event_target.appconfig_complete,
    aws_cloudwatch_event_target.appconfig_rollback,
  ]
}

resource "aws_appconfig_extension_association" "eventbridge" {
  extension_arn = "arn:${data.aws_partition.current.partition}:appconfig:${var.aws_region}::extension/AWS.AppConfig.DeploymentNotificationsToEventBridge/1"
  resource_arn  = aws_appconfig_environment.app.arn
}

# AWS AppConfig sends these service events directly to the default EventBridge
# bus on a best-effort basis. The association ARN identifies this environment
# even if a deployment event omits the optional Application/Environment names.
resource "aws_cloudwatch_event_rule" "appconfig_complete" {
  name = "${var.project_name}-appconfig-complete"
  event_pattern = jsonencode({
    source        = ["aws.appconfig"]
    "detail-type" = ["On Deployment Complete"]
    resources     = [aws_appconfig_extension_association.eventbridge.arn]
  })
}

resource "aws_cloudwatch_event_rule" "appconfig_rollback" {
  name = "${var.project_name}-appconfig-rollback"
  event_pattern = jsonencode({
    source        = ["aws.appconfig"]
    "detail-type" = ["On Deployment Rollback"]
    resources     = [aws_appconfig_extension_association.eventbridge.arn]
  })
}

resource "aws_cloudwatch_event_target" "appconfig_complete" {
  rule      = aws_cloudwatch_event_rule.appconfig_complete.name
  target_id = "sns-alerts"
  arn       = aws_sns_topic.alerts.arn

  depends_on = [aws_sns_topic_policy.alerts]
}

resource "aws_cloudwatch_event_target" "appconfig_rollback" {
  rule      = aws_cloudwatch_event_rule.appconfig_rollback.name
  target_id = "sns-alerts"
  arn       = aws_sns_topic.alerts.arn

  depends_on = [aws_sns_topic_policy.alerts]
}
