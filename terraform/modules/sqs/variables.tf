variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

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

variable "fulfill_order_lambda_arn" {
  description = "ARN of the Lambda function to process order queue messages"
  type        = string
}

variable "dlq_handler_lambda_arn" {
  description = "ARN of the Lambda function to process dead letter queue messages"
  type        = string
}