# SQS Queues for DOFS Order Processing System

# Main order processing queue
resource "aws_sqs_queue" "order_queue" {
  name                       = "${var.project_name}-${var.environment}-order-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = var.visibility_timeout_seconds

  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-order-queue"
    Component = "sqs"
    Purpose   = "order-processing"
  }
}

# Dead letter queue for failed order processing
resource "aws_sqs_queue" "order_dlq" {
  name                       = "${var.project_name}-${var.environment}-order-dlq"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = var.visibility_timeout_seconds

  tags = {
    Name      = "${var.project_name}-${var.environment}-order-dlq"
    Component = "sqs"
    Purpose   = "failed-order-handling"
  }
}

# Lambda trigger for processing messages from order queue
resource "aws_lambda_event_source_mapping" "order_queue_trigger" {
  event_source_arn = aws_sqs_queue.order_queue.arn
  function_name    = var.fulfill_order_lambda_arn
  batch_size       = 1
  enabled          = true

  depends_on = [
    aws_sqs_queue.order_queue
  ]
}

# Lambda trigger for processing messages from dead letter queue
resource "aws_lambda_event_source_mapping" "order_dlq_trigger" {
  event_source_arn = aws_sqs_queue.order_dlq.arn
  function_name    = var.dlq_handler_lambda_arn
  batch_size       = 1
  enabled          = true

  depends_on = [
    aws_sqs_queue.order_dlq
  ]
}