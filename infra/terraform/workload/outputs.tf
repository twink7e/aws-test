output "service_name" {
  description = "ECS web service name for CI deployment inspection."
  value       = aws_ecs_service.web.name
}

output "cluster_name" {
  description = "ECS cluster name for CI deployment inspection."
  value       = local.foundation.cluster_name
}

output "web_task_definition_arn" {
  description = "Current web task definition ARN."
  value       = aws_ecs_task_definition.web.arn
}

output "backup_task_definition_arn" {
  description = "Current backup task definition ARN."
  value       = aws_ecs_task_definition.backup.arn
}

output "app_url" {
  description = "Public URL for smoke tests."
  value       = local.app_url
}

output "backup_schedule_arn" {
  description = "Daily EventBridge Scheduler schedule ARN."
  value       = aws_scheduler_schedule.backup.arn
}

output "backup_schedule_group_name" {
  description = "Dedicated Scheduler group for backup controller invocation metrics."
  value       = aws_scheduler_schedule_group.backup.name
}

output "backup_controller_lambda_name" {
  description = "Lambda function that launches and checks ECS backup tasks."
  value       = aws_lambda_function.backup_controller.function_name
}

output "backup_controller_log_group_name" {
  description = "Foundation-managed log group for the backup controller Lambda."
  value       = local.foundation.backup_controller_log_group_name
}

output "dashboard_name" {
  description = "CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.operations.dashboard_name
}

output "alb_500_ratio_alarm_name" {
  description = "CloudWatch alarm for exact HTTP 500 response ratio."
  value       = aws_cloudwatch_metric_alarm.alb_exact_500_ratio.alarm_name
}

output "backup_failed_alarm_name" {
  description = "CloudWatch alarm for failed backup launches or ECS task exits."
  value       = aws_cloudwatch_metric_alarm.backup_failed.alarm_name
}
