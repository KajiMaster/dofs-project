# Lambda functions for DOFS Order Processing System

# Create Lambda deployment packages directory
resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "${var.project_name}-${var.environment}-lambda-deployments"
}

resource "aws_s3_bucket_versioning" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id
  versioning_configuration {
    status = "Enabled"
  }
}

# API Handler Lambda Function
resource "aws_lambda_function" "api_handler" {
  function_name = "${var.project_name}-${var.environment}-api-handler"
  role          = aws_iam_role.api_handler_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.api_handler_zip.output_path
  source_code_hash = data.archive_file.api_handler_zip.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME        = var.orders_table_name
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      STEP_FUNCTION_ARN        = var.step_function_arn
      ENVIRONMENT              = var.environment
      PROJECT_NAME             = var.project_name
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-api-handler"
    Component = "lambda"
    Purpose   = "api-handling"
  }
}

# Create Lambda function code
resource "local_file" "api_handler_code" {
  content = templatefile("${path.module}/src/api_handler.py", {
    orders_table_name        = var.orders_table_name
    failed_orders_table_name = var.failed_orders_table_name
  })
  filename = "${path.module}/dist/api_handler/index.py"
}

# Create zip file for Lambda deployment
data "archive_file" "api_handler_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/api_handler.zip"
  
  source {
    content  = local_file.api_handler_code.content
    filename = "index.py"
  }

  depends_on = [local_file.api_handler_code]
}

# IAM Role for API Handler Lambda
resource "aws_iam_role" "api_handler_role" {
  name = "${var.project_name}-${var.environment}-api-handler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-api-handler-role"
    Component = "lambda"
    Purpose   = "api-handling"
  }
}

# IAM Policy for API Handler Lambda
resource "aws_iam_role_policy" "api_handler_policy" {
  name = "${var.project_name}-${var.environment}-api-handler-policy"
  role = aws_iam_role.api_handler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.orders_table_arn,
          var.failed_orders_table_arn,
          "${var.orders_table_arn}/*",
          "${var.failed_orders_table_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.step_function_arn != "" ? [var.step_function_arn] : []
      }
    ]
  })
}

# Attach AWS managed policy for basic Lambda execution
resource "aws_iam_role_policy_attachment" "api_handler_basic_execution" {
  role       = aws_iam_role.api_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# VALIDATOR LAMBDA FUNCTION
# =============================================================================

resource "aws_lambda_function" "validator" {
  function_name = "${var.project_name}-${var.environment}-validator"
  role          = aws_iam_role.validator_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.validator_zip.output_path
  source_code_hash = data.archive_file.validator_zip.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-validator"
    Component = "lambda"
    Purpose   = "order-validation"
  }
}

resource "local_file" "validator_code" {
  content = templatefile("${path.module}/src/validator.py", {})
  filename = "${path.module}/dist/validator/index.py"
}

data "archive_file" "validator_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/validator.zip"
  
  source {
    content  = local_file.validator_code.content
    filename = "index.py"
  }

  depends_on = [local_file.validator_code]
}

resource "aws_iam_role" "validator_role" {
  name = "${var.project_name}-${var.environment}-validator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-validator-role"
    Component = "lambda"
    Purpose   = "order-validation"
  }
}

resource "aws_iam_role_policy_attachment" "validator_basic_execution" {
  role       = aws_iam_role.validator_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# ORDER STORAGE LAMBDA FUNCTION
# =============================================================================

resource "aws_lambda_function" "order_storage" {
  function_name = "${var.project_name}-${var.environment}-order-storage"
  role          = aws_iam_role.order_storage_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.order_storage_zip.output_path
  source_code_hash = data.archive_file.order_storage_zip.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
      ENVIRONMENT       = var.environment
      PROJECT_NAME      = var.project_name
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-order-storage"
    Component = "lambda"
    Purpose   = "order-storage"
  }
}

resource "local_file" "order_storage_code" {
  content = templatefile("${path.module}/src/order_storage.py", {
    orders_table_name = var.orders_table_name
  })
  filename = "${path.module}/dist/order_storage/index.py"
}

data "archive_file" "order_storage_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/order_storage.zip"
  
  source {
    content  = local_file.order_storage_code.content
    filename = "index.py"
  }

  depends_on = [local_file.order_storage_code]
}

resource "aws_iam_role" "order_storage_role" {
  name = "${var.project_name}-${var.environment}-order-storage-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-order-storage-role"
    Component = "lambda"
    Purpose   = "order-storage"
  }
}

resource "aws_iam_role_policy" "order_storage_policy" {
  name = "${var.project_name}-${var.environment}-order-storage-policy"
  role = aws_iam_role.order_storage_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.orders_table_arn,
          "${var.orders_table_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "order_storage_basic_execution" {
  role       = aws_iam_role.order_storage_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# FULFILLMENT LAMBDA FUNCTION
# =============================================================================

resource "aws_lambda_function" "fulfill_order" {
  function_name = "${var.project_name}-${var.environment}-fulfill-order"
  role          = aws_iam_role.fulfill_order_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.fulfill_order_zip.output_path
  source_code_hash = data.archive_file.fulfill_order_zip.output_base64sha256

  environment {
    variables = {
      ORDERS_TABLE_NAME        = var.orders_table_name
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      SUCCESS_RATE             = var.fulfillment_success_rate
      ENVIRONMENT              = var.environment
      PROJECT_NAME             = var.project_name
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-fulfill-order"
    Component = "lambda"
    Purpose   = "order-fulfillment"
  }
}

resource "local_file" "fulfill_order_code" {
  content = templatefile("${path.module}/src/fulfill_order.py", {
    orders_table_name        = var.orders_table_name
    failed_orders_table_name = var.failed_orders_table_name
  })
  filename = "${path.module}/dist/fulfill_order/index.py"
}

data "archive_file" "fulfill_order_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/fulfill_order.zip"
  
  source {
    content  = local_file.fulfill_order_code.content
    filename = "index.py"
  }

  depends_on = [local_file.fulfill_order_code]
}

resource "aws_iam_role" "fulfill_order_role" {
  name = "${var.project_name}-${var.environment}-fulfill-order-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-fulfill-order-role"
    Component = "lambda"
    Purpose   = "order-fulfillment"
  }
}

resource "aws_iam_role_policy" "fulfill_order_policy" {
  name = "${var.project_name}-${var.environment}-fulfill-order-policy"
  role = aws_iam_role.fulfill_order_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.orders_table_arn,
          var.failed_orders_table_arn,
          "${var.orders_table_arn}/*",
          "${var.failed_orders_table_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fulfill_order_basic_execution" {
  role       = aws_iam_role.fulfill_order_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# DLQ HANDLER LAMBDA FUNCTION
# =============================================================================

resource "aws_lambda_function" "dlq_handler" {
  function_name = "${var.project_name}-${var.environment}-dlq-handler"
  role          = aws_iam_role.dlq_handler_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.dlq_handler_zip.output_path
  source_code_hash = data.archive_file.dlq_handler_zip.output_base64sha256

  environment {
    variables = {
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      ENVIRONMENT              = var.environment
      PROJECT_NAME             = var.project_name
    }
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-dlq-handler"
    Component = "lambda"
    Purpose   = "dlq-processing"
  }
}

resource "local_file" "dlq_handler_code" {
  content  = templatefile("${path.module}/src/dlq_handler.py", {})
  filename = "${path.module}/dist/dlq_handler/index.py"
}

data "archive_file" "dlq_handler_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/dlq_handler.zip"

  source {
    content  = local_file.dlq_handler_code.content
    filename = "index.py"
  }

  depends_on = [local_file.dlq_handler_code]
}

resource "aws_iam_role" "dlq_handler_role" {
  name = "${var.project_name}-${var.environment}-dlq-handler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-dlq-handler-role"
    Component = "lambda"
    Purpose   = "dlq-processing"
  }
}

resource "aws_iam_role_policy" "dlq_handler_policy" {
  name = "${var.project_name}-${var.environment}-dlq-handler-policy"
  role = aws_iam_role.dlq_handler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = [
          var.failed_orders_table_arn,
          "${var.failed_orders_table_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dlq_handler_basic_execution" {
  role       = aws_iam_role.dlq_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}