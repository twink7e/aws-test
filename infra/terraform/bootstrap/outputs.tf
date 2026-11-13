output "state_bucket_name" {
  description = "Use this bucket in foundation and workload backend.hcl files."
  value       = aws_s3_bucket.state.id
}

output "aws_region" {
  value = var.aws_region
}
