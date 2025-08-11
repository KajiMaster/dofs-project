project_name = "dofs"
environment  = "global"
aws_region   = "us-east-1"

# Terraform state configuration (externally managed)
terraform_state_bucket = "dofs-global-terraform-state-5ju06wiy"
terraform_locks_table  = "dofs-global-terraform-locks"

# CodeBuild configuration
codebuild_compute_type = "BUILD_GENERAL1_SMALL"
codebuild_image        = "aws/codebuild/standard:7.0"

# GitHub repository configuration for CI/CD
# Update these values when handing off to client
github_repo = "KajiMaster/dofs-project"
github_token = ""  # Leave empty to use AWS Systems Manager Parameter Store