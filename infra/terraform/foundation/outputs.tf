output "aws_region" { value = var.aws_region }
output "account_id" { value = local.account_id }
output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_db_subnet_ids" { value = aws_subnet.private_db[*].id }
output "ecs_security_group_id" { value = aws_security_group.ecs.id }

output "alb_arn" { value = aws_lb.app.arn }
output "alb_arn_suffix" { value = aws_lb.app.arn_suffix }
output "alb_dns_name" { value = aws_lb.app.dns_name }
output "alb_url" { value = "${var.acm_certificate_arn == null ? "http" : "https"}://${aws_lb.app.dns_name}" }
output "alb_target_group_arn" { value = aws_lb_target_group.web.arn }

output "cluster_arn" { value = aws_ecs_cluster.app.arn }
output "cluster_name" { value = aws_ecs_cluster.app.name }
output "ecs_service_linked_role_arn" { value = aws_iam_service_linked_role.ecs.arn }
output "ecs_autoscaling_service_linked_role_arn" { value = aws_iam_service_linked_role.ecs_application_autoscaling.arn }
output "iam_permissions_boundary_arn" { value = local.iam_permissions_boundary_arn }
output "task_execution_role_arn" { value = aws_iam_role.task_execution.arn }
output "app_task_role_arn" { value = aws_iam_role.app_task.arn }
output "backup_task_role_arn" { value = aws_iam_role.backup_task.arn }
output "backup_scheduler_role_arn" { value = aws_iam_role.backup_scheduler.arn }
output "backup_controller_lambda_role_arn" { value = aws_iam_role.backup_controller_lambda.arn }
output "backup_controller_log_group_name" { value = aws_cloudwatch_log_group.backup_controller.name }

output "ecr_app_repository_url" { value = aws_ecr_repository.app.repository_url }
output "ecr_web_repository_url" { value = aws_ecr_repository.web.repository_url }
output "ecr_backup_repository_url" { value = aws_ecr_repository.backup.repository_url }

output "app_log_group_name" { value = aws_cloudwatch_log_group.app.name }
output "web_log_group_name" { value = aws_cloudwatch_log_group.web.name }
output "agent_log_group_name" { value = aws_cloudwatch_log_group.agent.name }
output "backup_log_group_name" { value = aws_cloudwatch_log_group.backup.name }
output "alb_log_group_name" { value = aws_cloudwatch_log_group.alb_access.name }
output "app_error_alarm_name" { value = aws_cloudwatch_metric_alarm.app_error.alarm_name }
output "app_error_alarm_arn" { value = aws_cloudwatch_metric_alarm.app_error.arn }

output "db_endpoint" { value = aws_db_instance.postgres.address }
output "db_port" { value = aws_db_instance.postgres.port }
output "db_name" { value = aws_db_instance.postgres.db_name }
output "db_username" { value = aws_db_instance.postgres.username }
output "db_password_secret_arn" { value = aws_db_instance.postgres.master_user_secret[0].secret_arn }
output "app_key_secret_arn" { value = aws_secretsmanager_secret.app_key.arn }
output "backup_bucket_name" { value = aws_s3_bucket.backup.id }
output "sns_topic_arn" { value = aws_sns_topic.alerts.arn }

output "appconfig_application_name" { value = aws_appconfig_application.app.name }
output "appconfig_application_id" { value = aws_appconfig_application.app.id }
output "appconfig_environment_name" { value = aws_appconfig_environment.app.name }
output "appconfig_environment_id" { value = aws_appconfig_environment.app.environment_id }
output "appconfig_profile_name" { value = aws_appconfig_configuration_profile.runtime.name }
output "appconfig_profile_id" { value = aws_appconfig_configuration_profile.runtime.configuration_profile_id }
output "appconfig_gradual_strategy_id" { value = aws_appconfig_deployment_strategy.gradual.id }
output "appconfig_deployment_number" { value = aws_appconfig_deployment.initial.deployment_number }
