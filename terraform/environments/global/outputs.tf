# Note: State infrastructure (S3/DynamoDB) is managed externally
# These outputs reference the externally managed resources:

output "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state (externally managed)"
  value       = var.terraform_state_bucket
}

output "terraform_locks_table" {
  description = "Name of the DynamoDB table for Terraform locks (externally managed)"  
  value       = var.terraform_locks_table
}