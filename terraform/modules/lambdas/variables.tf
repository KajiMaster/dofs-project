variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

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

variable "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  type        = string
}

variable "orders_table_arn" {
  description = "ARN of the orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_name" {
  description = "Name of the failed orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_arn" {
  description = "ARN of the failed orders DynamoDB table"
  type        = string
}

variable "fulfillment_success_rate" {
  description = "Success rate for order fulfillment (0.0 to 1.0)"
  type        = number
  default     = 0.7
}

variable "step_function_arn" {
  description = "ARN of the Step Functions state machine"
  type        = string
  default     = ""
}