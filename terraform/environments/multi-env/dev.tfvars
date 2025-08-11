# Development environment configuration
project_name = "dofs"
environment  = "dev"
aws_region   = "us-east-1"
terraform_state_bucket = "dofs-global-terraform-state-5ju06wiy"

# Lambda configuration
lambda_runtime     = "python3.11"
lambda_timeout     = 30
lambda_memory_size = 128

# Order fulfillment configuration
fulfillment_success_rate = 0.7

# SQS configuration
message_retention_seconds   = 1209600  # 14 days
visibility_timeout_seconds = 30