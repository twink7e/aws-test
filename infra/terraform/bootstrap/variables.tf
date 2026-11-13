variable "aws_region" {
  description = "AWS Region used for the remote state bucket."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = var.aws_region == "ap-northeast-1"
    error_message = "This assessment must deploy in AWS Tokyo (ap-northeast-1)."
  }
}

variable "project_name" {
  description = "Lowercase, hyphenated project name used in bucket names."
  type        = string
  default     = "poper-test"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,22}$", var.project_name))
    error_message = "project_name must contain 3-23 lowercase letters, digits, or hyphens and start with a letter."
  }
}
