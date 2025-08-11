# Backend configuration for remote state
# Note: Backend blocks cannot use interpolation, so values are hardcoded
# Workspaces provide environment separation: env:/dev/terraform.tfstate, env:/staging/terraform.tfstate
terraform {
  backend "s3" {
    bucket         = "dofs-global-terraform-state-5ju06wiy"
    key            = "terraform.tfstate"
    region         = "us-east-1" 
    use_lockfile   = true
    dynamodb_table = "dofs-global-terraform-locks"
    encrypt        = true
  }
}