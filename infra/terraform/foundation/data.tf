data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = "17"
  latest  = true
}

locals {
  account_id                   = data.aws_caller_identity.current.account_id
  db_identifier                = "${var.project_name}-postgres"
  backup_bucket                = "${var.project_name}-${local.account_id}-${var.aws_region}-backup"
  iam_role_prefix              = "itv-${var.project_name}"
  iam_permissions_boundary_arn = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/InterviewCandidate-Boundary"
}
