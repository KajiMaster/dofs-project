# Step Functions State Machine for DOFS Order Processing System

# IAM Role for Step Functions
resource "aws_iam_role" "stepfunctions_role" {
  name = "${var.project_name}-${var.environment}-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-stepfunctions-role"
    Component = "stepfunctions"
    Purpose   = "order-orchestration"
  }
}

# IAM Policy for Step Functions
resource "aws_iam_role_policy" "stepfunctions_policy" {
  name = "${var.project_name}-${var.environment}-stepfunctions-policy"
  role = aws_iam_role.stepfunctions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.validator_function_arn,
          var.order_storage_function_arn,
          var.fulfill_order_function_arn,
          "${var.validator_function_arn}:*",
          "${var.order_storage_function_arn}:*",
          "${var.fulfill_order_function_arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = [
          var.order_queue_arn,
          var.order_dlq_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "order_processing" {
  name     = "${var.project_name}-${var.environment}-order-processing"
  role_arn = aws_iam_role.stepfunctions_role.arn

  definition = jsonencode({
    Comment = "DOFS Order Processing State Machine"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = var.validator_function_arn
        Next     = "CheckValidation"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 1
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "ValidationFailed"
            ResultPath  = "$.error"
          }
        ]
      }
      
      CheckValidation = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.validation_result"
            StringEquals  = "PASSED"
            Next         = "StoreOrder"
          }
        ]
        Default = "ValidationFailed"
      }
      
      StoreOrder = {
        Type     = "Task"
        Resource = var.order_storage_function_arn
        Next     = "CheckStorage"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 1
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "StorageFailed"
            ResultPath  = "$.error"
          }
        ]
      }
      
      CheckStorage = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.storage_result"
            StringEquals  = "SUCCESS"
            Next         = "SendToQueue"
          }
        ]
        Default = "StorageFailed"
      }
      
      SendToQueue = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl       = var.order_queue_url
          "MessageBody.$" = "$"
        }
        Next = "QueueSent"
        Retry = [
          {
            ErrorEquals = ["SqsSendMessageFailed"]
            IntervalSeconds = 1
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "QueueFailed"
            ResultPath  = "$.error"
          }
        ]
      }
      
      QueueSent = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS"
          message = "Order sent to processing queue"
        }
        End = true
      }
      
      ValidationFailed = {
        Type = "Pass"
        Result = {
          status  = "FAILED"
          message = "Order validation failed"
          stage   = "validation"
        }
        End = true
      }
      
      StorageFailed = {
        Type = "Pass"
        Result = {
          status  = "FAILED"
          message = "Order storage failed"
          stage   = "storage"
        }
        End = true
      }
      
      QueueFailed = {
        Type = "Pass"
        Result = {
          status  = "FAILED"
          message = "Failed to send order to queue"
          stage   = "queuing"
        }
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.stepfunctions.arn}:*"
    include_execution_data = true
    level                 = "ALL"
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-order-processing"
    Component = "stepfunctions"
    Purpose   = "order-orchestration"
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "stepfunctions" {
  name              = "/aws/stepfunctions/${var.project_name}-${var.environment}-order-processing"
  retention_in_days = 14

  tags = {
    Name      = "${var.project_name}-${var.environment}-stepfunctions-logs"
    Component = "stepfunctions"
    Purpose   = "logging"
  }
}

# Note: SQS event source mapping is managed in the SQS module