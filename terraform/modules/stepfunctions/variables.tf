variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "validator_function_arn" {
  description = "ARN of the validator Lambda function"
  type        = string
}

variable "order_storage_function_arn" {
  description = "ARN of the order storage Lambda function"
  type        = string
}

variable "fulfill_order_function_arn" {
  description = "ARN of the fulfill order Lambda function"
  type        = string
}

variable "order_queue_url" {
  description = "URL of the order processing queue"
  type        = string
}

variable "order_queue_arn" {
  description = "ARN of the order processing queue"
  type        = string
}

variable "order_dlq_arn" {
  description = "ARN of the order dead letter queue"
  type        = string
}