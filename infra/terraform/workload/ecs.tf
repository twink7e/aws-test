# One awsvpc task contains Nginx, PHP-FPM, and the AppConfig Agent. The ALB
# reaches Nginx on 8080; Nginx reaches PHP-FPM within the task on localhost:9000.
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.name_prefix}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.web_task_cpu
  memory                   = var.web_task_memory
  execution_role_arn       = local.foundation.task_execution_role_arn
  task_role_arn            = local.foundation.app_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.app_image
      essential = true
      portMappings = [
        { containerPort = 9000, protocol = "tcp" }
      ]
      environment = [
        { name = "APP_ENV", value = "production" },
        { name = "APP_DEBUG", value = "false" },
        { name = "APP_URL", value = local.app_url },
        { name = "LOG_CHANNEL", value = "stderr" },
        { name = "LOG_LEVEL", value = "info" },
        { name = "DB_CONNECTION", value = "pgsql" },
        { name = "DB_HOST", value = local.foundation.db_endpoint },
        { name = "DB_PORT", value = tostring(local.foundation.db_port) },
        { name = "DB_DATABASE", value = local.foundation.db_name },
        { name = "DB_USERNAME", value = local.foundation.db_username },
        { name = "DEMO_MESSAGE", value = var.demo_message },
        { name = "ENABLE_DEMO_FAILURE_ROUTES", value = tostring(var.enable_demo_failure_routes) },
        { name = "APPCONFIG_URL", value = local.appconfig_url },
        { name = "AWS_REGION", value = var.aws_region }
      ]
      secrets = [
        { name = "APP_KEY", valueFrom = local.foundation.app_key_secret_arn },
        { name = "DB_PASSWORD", valueFrom = "${local.foundation.db_password_secret_arn}:password::" }
      ]
      dependsOn = [
        { containerName = "appconfig-agent", condition = "START" }
      ]
      ulimits = [
        { name = "nofile", softLimit = 131072, hardLimit = 131072 }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.awslogs_common, { "awslogs-group" = local.foundation.app_log_group_name })
      }
    },
    {
      name      = "web"
      image     = var.web_image
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      dependsOn = [
        { containerName = "app", condition = "START" }
      ]
      ulimits = [
        { name = "nofile", softLimit = 131072, hardLimit = 131072 }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.awslogs_common, { "awslogs-group" = local.foundation.web_log_group_name })
      }
    },
    {
      name      = "appconfig-agent"
      image     = var.appconfig_agent_image
      essential = true
      portMappings = [
        { containerPort = 2772, protocol = "tcp" }
      ]
      environment = [
        { name = "SERVICE_REGION", value = var.aws_region },
        { name = "POLL_INTERVAL", value = var.appconfig_poll_interval },
        { name = "PREFETCH_LIST", value = "${local.foundation.appconfig_application_name}:${local.foundation.appconfig_environment_name}:${local.foundation.appconfig_profile_name}" }
      ]
      ulimits = [
        { name = "nofile", softLimit = 131072, hardLimit = 131072 }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = merge(local.awslogs_common, { "awslogs-group" = local.foundation.agent_log_group_name })
      }
    }
  ])
}

resource "aws_ecs_service" "web" {
  name                   = "${var.name_prefix}-web"
  cluster                = local.foundation.cluster_arn
  task_definition        = aws_ecs_task_definition.web.arn
  desired_count          = local.initial_replicas
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  enable_execute_command = false
  wait_for_steady_state  = true

  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = local.foundation.public_subnet_ids
    security_groups  = [local.foundation.ecs_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = local.foundation.alb_target_group_arn
    container_name   = "web"
    container_port   = 8080
  }

  # Application Auto Scaling owns desired_count after the first deployment.
  lifecycle {
    ignore_changes = [desired_count]
  }
}
