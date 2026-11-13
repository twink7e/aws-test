resource "aws_appautoscaling_target" "web" {
  max_capacity       = local.initial_replicas
  min_capacity       = local.initial_replicas
  resource_id        = "service/${local.foundation.cluster_name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  # Scheduled actions intentionally mutate these bounds every day.
  lifecycle {
    ignore_changes = [min_capacity, max_capacity]
  }
}

# The schedule changes the minimum and maximum together, so the service is
# exactly 2 tasks from 17:00 to 17:59 and exactly 1 task at other times.
resource "aws_appautoscaling_scheduled_action" "evening_start" {
  name               = "${var.name_prefix}-17h-two-tasks"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  schedule           = "cron(0 17 * * ? *)"
  timezone           = "Asia/Tokyo"

  scalable_target_action {
    min_capacity = 2
    max_capacity = 2
  }
}

resource "aws_appautoscaling_scheduled_action" "evening_end" {
  name               = "${var.name_prefix}-18h-one-task"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  schedule           = "cron(0 18 * * ? *)"
  timezone           = "Asia/Tokyo"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}
