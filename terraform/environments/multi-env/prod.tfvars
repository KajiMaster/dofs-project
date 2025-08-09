# Production environment configuration
project_name = "dofs"
environment  = "prod"
aws_region   = "us-east-1"

# Global state bucket (hardcoded since backend can't interpolate)
terraform_state_bucket = "dofs-global-terraform-state-5ju06wiy"

# Lambda configuration
lambda_runtime     = "python3.11"
lambda_timeout     = 30
lambda_memory_size = 256  # More memory for production

# Order fulfillment configuration
fulfillment_success_rate = 0.9  # Higher success rate in production

# SQS configuration
message_retention_seconds   = 1209600  # 14 days
visibility_timeout_seconds = 30