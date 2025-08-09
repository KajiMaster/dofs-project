terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Note: S3 bucket and DynamoDB table for Terraform state are managed externally
# These resources exist but are not managed by this Terraform configuration:
# - S3 Bucket: dofs-global-terraform-state-5ju06wiy
# - DynamoDB Table: dofs-global-terraform-locks
#
# This avoids the bootstrap paradox and enables team collaboration while
# maintaining clean separation between state infrastructure and application infrastructure.