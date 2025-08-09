# DynamoDB Tables for DOFS Order Processing System

# Orders table - stores all incoming orders
resource "aws_dynamodb_table" "orders" {
  name           = "${var.project_name}-${var.environment}-orders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  # Optional: Add GSI for querying by status if needed
  attribute {
    name = "order_status"
    type = "S"
  }

  global_secondary_index {
    name               = "status-index"
    hash_key           = "order_status"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-orders"
    Component   = "database"
    Purpose     = "order-storage"
  }
}

# Failed Orders table - stores orders that failed processing
resource "aws_dynamodb_table" "failed_orders" {
  name           = "${var.project_name}-${var.environment}-failed-orders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  # Optional: Add attribute for failure timestamp for querying
  attribute {
    name = "failure_timestamp"
    type = "S"
  }

  global_secondary_index {
    name               = "failure-time-index"
    hash_key           = "failure_timestamp"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-failed-orders"
    Component   = "database"
    Purpose     = "failed-order-storage"
  }
}