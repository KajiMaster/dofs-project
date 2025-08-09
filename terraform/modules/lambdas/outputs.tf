output "api_handler_function_name" {
  description = "Name of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "api_handler_function_arn" {
  description = "ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.arn
}

output "api_handler_invoke_arn" {
  description = "Invoke ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.invoke_arn
}

output "api_handler_role_arn" {
  description = "ARN of the API handler Lambda execution role"
  value       = aws_iam_role.api_handler_role.arn
}

# Validator Lambda outputs
output "validator_function_name" {
  description = "Name of the validator Lambda function"
  value       = aws_lambda_function.validator.function_name
}

output "validator_function_arn" {
  description = "ARN of the validator Lambda function"
  value       = aws_lambda_function.validator.arn
}

# Order Storage Lambda outputs
output "order_storage_function_name" {
  description = "Name of the order storage Lambda function"
  value       = aws_lambda_function.order_storage.function_name
}

output "order_storage_function_arn" {
  description = "ARN of the order storage Lambda function"
  value       = aws_lambda_function.order_storage.arn
}

# Fulfillment Lambda outputs
output "fulfill_order_function_name" {
  description = "Name of the fulfill order Lambda function"
  value       = aws_lambda_function.fulfill_order.function_name
}

output "fulfill_order_function_arn" {
  description = "ARN of the fulfill order Lambda function"
  value       = aws_lambda_function.fulfill_order.arn
}

output "dlq_handler_function_arn" {
  description = "ARN of the DLQ handler Lambda function"
  value       = aws_lambda_function.dlq_handler.arn
}