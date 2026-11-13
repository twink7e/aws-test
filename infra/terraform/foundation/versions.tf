terraform {
  required_version = ">= 1.14.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "foundation"
    }
  }
}

# IAM service-linked roles are AWS-managed and the candidate cannot tag roles
# outside the itv-* prefix. Keep this provider free of default tags for them.
provider "aws" {
  alias  = "untagged"
  region = var.aws_region
}
