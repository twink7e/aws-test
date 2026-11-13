# The candidate identity may create these AWS-managed service-linked roles.
# Create them in the trusted foundation apply so CI never needs IAM role creation.
resource "aws_iam_service_linked_role" "ecs" {
  provider         = aws.untagged
  aws_service_name = "ecs.amazonaws.com"
  description      = "Amazon ECS service-linked role for the interview cluster"
}

resource "aws_iam_service_linked_role" "ecs_application_autoscaling" {
  provider         = aws.untagged
  aws_service_name = "ecs.application-autoscaling.amazonaws.com"
  description      = "Application Auto Scaling service-linked role for ECS service capacity"
}
