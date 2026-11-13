resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db"
  subnet_ids = aws_subnet.private_db[*].id
  tags       = { Name = "${var.project_name}-db" }
}

resource "aws_db_instance" "postgres" {
  identifier                      = local.db_identifier
  engine                          = "postgres"
  engine_version                  = data.aws_rds_engine_version.postgres.version_actual
  instance_class                  = var.db_instance_class
  allocated_storage               = var.db_allocated_storage_gib
  max_allocated_storage           = var.db_max_allocated_storage_gib
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = var.db_name
  username                        = var.db_username
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.db.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  publicly_accessible             = false
  multi_az                        = false
  backup_retention_period         = 1
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  deletion_protection             = false
  skip_final_snapshot             = true
  apply_immediately               = true
  auto_minor_version_upgrade      = true

  depends_on = [
    aws_cloudwatch_log_group.rds_postgresql,
    aws_cloudwatch_log_group.rds_upgrade,
  ]

  tags = { Name = local.db_identifier }
}
