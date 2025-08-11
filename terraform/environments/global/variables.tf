variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dofs"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "global"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (externally managed)"
  type        = string
  default     = "dofs-global-terraform-state-5ju06wiy"
}

variable "terraform_locks_table" {
  description = "DynamoDB table name for Terraform locks (externally managed)"
  type        = string
  default     = "dofs-global-terraform-locks"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type (e.g., BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM)"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "CodeBuild image to use (e.g., aws/codebuild/standard:7.0)"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}