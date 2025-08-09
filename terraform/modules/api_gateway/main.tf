# API Gateway for DOFS Order Processing System

# REST API Gateway
resource "aws_api_gateway_rest_api" "dofs_api" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "DOFS Order Processing API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name      = "${var.project_name}-${var.environment}-api"
    Component = "api-gateway"
    Purpose   = "order-processing"
  }
}

# Resource for /order endpoint
resource "aws_api_gateway_resource" "order" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  parent_id   = aws_api_gateway_rest_api.dofs_api.root_resource_id
  path_part   = "order"
}

# POST method for /order endpoint
resource "aws_api_gateway_method" "order_post" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.order.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.order_validator.id
  
  request_models = {
    "application/json" = aws_api_gateway_model.order_model.name
  }
}

# Request validator for input validation
resource "aws_api_gateway_request_validator" "order_validator" {
  name                        = "${var.project_name}-${var.environment}-order-validator"
  rest_api_id                 = aws_api_gateway_rest_api.dofs_api.id
  validate_request_body       = true
  validate_request_parameters = false
}

# Request model for order validation
resource "aws_api_gateway_model" "order_model" {
  rest_api_id  = aws_api_gateway_rest_api.dofs_api.id
  name         = "OrderModel"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Order Schema"
    type      = "object"
    required  = ["customer_id", "items"]
    properties = {
      customer_id = {
        type = "string"
      }
      items = {
        type = "array"
        items = {
          type = "object"
          required = ["product_id", "quantity"]
          properties = {
            product_id = {
              type = "string"
            }
            quantity = {
              type = "integer"
              minimum = 1
            }
          }
        }
      }
    }
  })
}

# Integration with Lambda function
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# Method response
resource "aws_api_gateway_method_response" "order_response_200" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# Integration response
resource "aws_api_gateway_integration_response" "lambda_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.order_post.http_method
  status_code = aws_api_gateway_method_response.order_response_200.status_code

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "dofs_deployment" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.order.id,
      aws_api_gateway_method.order_post.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.order_post,
    aws_api_gateway_integration.lambda_integration,
  ]
}

# API Gateway stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.dofs_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  stage_name    = var.environment

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-stage"
    Component   = "api-gateway"
    Environment = var.environment
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.dofs_api.execution_arn}/*/*"
}