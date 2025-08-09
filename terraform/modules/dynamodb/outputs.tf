output "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  value       = aws_dynamodb_table.orders.name
}

output "orders_table_arn" {
  description = "ARN of the orders DynamoDB table"
  value       = aws_dynamodb_table.orders.arn
}

output "failed_orders_table_name" {
  description = "Name of the failed orders DynamoDB table"
  value       = aws_dynamodb_table.failed_orders.name
}

output "failed_orders_table_arn" {
  description = "ARN of the failed orders DynamoDB table"
  value       = aws_dynamodb_table.failed_orders.arn
}