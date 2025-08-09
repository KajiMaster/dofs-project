terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Workspace-based environment detection
locals {
  workspace_name = terraform.workspace
  environment    = var.environment != null ? var.environment : terraform.workspace
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = local.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# Data source to get global infrastructure outputs
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "global/terraform.tfstate"
    region = var.aws_region
  }
}

# DynamoDB tables for this environment
module "dynamodb" {
  source = "../../modules/dynamodb"

  project_name = var.project_name
  environment  = local.environment
}

# ==== PHASE 2: API GATEWAY + LAMBDA (ACTIVE) ====

# Lambda functions (must come first for API Gateway to reference)
module "lambdas" {
  source = "../../modules/lambdas"

  project_name = var.project_name
  environment  = local.environment
  
  orders_table_name        = module.dynamodb.orders_table_name
  orders_table_arn         = module.dynamodb.orders_table_arn
  failed_orders_table_name = module.dynamodb.failed_orders_table_name
  failed_orders_table_arn  = module.dynamodb.failed_orders_table_arn
  step_function_arn        = try(module.stepfunctions.state_machine_arn, "")
  
  lambda_runtime     = var.lambda_runtime
  lambda_timeout     = var.lambda_timeout
  lambda_memory_size = var.lambda_memory_size
}

# API Gateway
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name = var.project_name
  environment  = local.environment
  
  lambda_function_name = module.lambdas.api_handler_function_name
  lambda_invoke_arn    = module.lambdas.api_handler_invoke_arn
}

# ==== PHASE 3: SQS + STEP FUNCTIONS (ACTIVE) ====

# SQS queues
module "sqs" {
  source = "../../modules/sqs"

  project_name = var.project_name
  environment  = local.environment
  
  fulfill_order_lambda_arn = module.lambdas.fulfill_order_function_arn
  dlq_handler_lambda_arn   = module.lambdas.dlq_handler_function_arn
}

# Step Functions
module "stepfunctions" {
  source = "../../modules/stepfunctions"

  project_name = var.project_name
  environment  = local.environment
  
  validator_function_arn     = module.lambdas.validator_function_arn
  order_storage_function_arn = module.lambdas.order_storage_function_arn
  fulfill_order_function_arn = module.lambdas.fulfill_order_function_arn
  order_queue_url            = module.sqs.order_queue_url
  order_queue_arn            = module.sqs.order_queue_arn
  order_dlq_arn              = module.sqs.order_dlq_arn
}

# # Monitoring (optional)
# module "monitoring" {
#   source = "../../modules/monitoring"
#
#   project_name = var.project_name
#   environment  = local.environment
#   
#   api_gateway_id       = module.api_gateway.api_gateway_id
#   step_function_arn    = module.stepfunctions.step_function_arn
#   lambda_function_arns = module.lambdas.all_function_arns
# }