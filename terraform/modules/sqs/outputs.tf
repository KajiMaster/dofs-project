output "order_queue_url" {
  description = "URL of the order processing queue"
  value       = aws_sqs_queue.order_queue.url
}

output "order_queue_arn" {
  description = "ARN of the order processing queue"
  value       = aws_sqs_queue.order_queue.arn
}

output "order_dlq_url" {
  description = "URL of the order dead letter queue"
  value       = aws_sqs_queue.order_dlq.url
}

output "order_dlq_arn" {
  description = "ARN of the order dead letter queue"
  value       = aws_sqs_queue.order_dlq.arn
}