# Backend configuration for global environment
# Uses the externally managed S3 bucket and DynamoDB table
terraform {
  backend "s3" {
    bucket         = "dofs-global-terraform-state-5ju06wiy"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dofs-global-terraform-locks"
    encrypt        = true
  }
}