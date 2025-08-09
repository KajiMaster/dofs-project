# Phase 1 Outputs - DynamoDB
output "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  value       = module.dynamodb.orders_table_name
}

output "failed_orders_table_name" {
  description = "Name of the failed orders DynamoDB table"
  value       = module.dynamodb.failed_orders_table_name
}

# Phase 2 Outputs - API Gateway + Lambda
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.api_gateway.api_gateway_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_gateway_id
}

output "api_handler_function_name" {
  description = "Name of the API handler Lambda function"
  value       = module.lambdas.api_handler_function_name
}

# ==== PHASE 3+ OUTPUTS (COMMENTED OUT) ====
# output "step_function_arn" {
#   description = "ARN of the Step Function"
#   value       = module.stepfunctions.step_function_arn
# }

# output "order_queue_url" {
#   description = "URL of the order queue"
#   value       = module.sqs.order_queue_url
# }

# Environment-specific outputs
output "environment_info" {
  description = "Environment configuration summary"
  value = {
    environment              = var.environment
    project_name            = var.project_name
    aws_region              = var.aws_region
    fulfillment_success_rate = var.fulfillment_success_rate
  }
}