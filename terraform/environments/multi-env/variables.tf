variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dofs"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (from global environment)"
  type        = string
}

# Lambda configuration
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions"
  type        = number
  default     = 128
}

# Order fulfillment configuration
variable "fulfillment_success_rate" {
  description = "Success rate for order fulfillment (0.0 to 1.0)"
  type        = number
  default     = 0.7
}

# SQS configuration
variable "message_retention_seconds" {
  description = "Message retention period for SQS queues"
  type        = number
  default     = 1209600  # 14 days
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for SQS messages"
  type        = number
  default     = 30
}