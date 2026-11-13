data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = var.foundation_state_bucket
    key    = var.foundation_state_key
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  foundation = data.terraform_remote_state.foundation.outputs
  app_url    = var.app_url != "" ? var.app_url : local.foundation.alb_url

  appconfig_url = "http://127.0.0.1:2772/applications/${local.foundation.appconfig_application_name}/environments/${local.foundation.appconfig_environment_name}/configurations/${local.foundation.appconfig_profile_name}"

  # Tokyo does not observe daylight saving time. Seed a new ECS service at
  # the right size even if first apply happens during the 17:00 hour.
  initial_replicas = tonumber(formatdate("hh", timeadd(plantimestamp(), "9h"))) == 17 ? 2 : 1

  awslogs_common = {
    "awslogs-region"        = var.aws_region
    "awslogs-stream-prefix" = "ecs"
  }
}
