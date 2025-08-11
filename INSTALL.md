# DOFS Installation Guide

Complete setup guide for the Distributed Order Fulfillment System.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Git
- GitHub repository set up

## 1. Initial Setup

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/dofs-project.git
cd dofs-project

# Set up AWS profile (recommended for isolation)
aws configure set region us-east-1 --profile dofs-project
export AWS_PROFILE=dofs-project
```

## 2. Bootstrap State Management (One-time)

⚠️ **Critical**: This creates the S3/DynamoDB backend for Terraform state.

```bash
# Deploy global infrastructure (S3 backend + CI/CD)
cd terraform/environments/global
terraform init
terraform apply

# Note the outputs - you'll need these values
terraform output
```

**Important State Management Notes:**
- The S3 bucket and DynamoDB table store Terraform state
- Before destroying global infrastructure, you MUST remove them from state:
  ```bash
  # Only do this when permanently shutting down the project
  terraform state rm aws_s3_bucket.terraform_state
  terraform state rm aws_dynamodb_table.terraform_locks
  ```
- This prevents Terraform from deleting the bucket containing its own state file

## 3. Configure Backend

After step 2, update the backend configuration:

```bash
cd ../multi-env
```

Update `backend.tf` with the S3 bucket name from step 2 outputs:
```hcl
terraform {
  backend "s3" {
    bucket         = "dofs-global-terraform-state-SUFFIX"
    key            = "dofs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dofs-global-terraform-locks"
    encrypt        = true
  }
}
```

## 4. Set Up GitHub Integration

### Option A: CodeStar Connection (Recommended)
1. Go to AWS CodeStar Connections console
2. Create connection to GitHub
3. Note the connection ARN

### Option B: Personal Access Token (Legacy)

⚠️ **Important**: Store GitHub token securely in AWS Parameter Store

1. **Create GitHub Personal Access Token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Create token with `repo` permissions
   - Copy the token (you won't see it again!)

2. **Store token in AWS Systems Manager Parameter Store**:
   ```bash
   aws ssm put-parameter \
     --name "/github/personal-access-token" \
     --value "ghp_your_actual_github_token_here" \
     --type "SecureString" \
     --description "GitHub PAT for DOFS CI/CD pipelines"
   ```

3. **Verify parameter is stored**:
   ```bash
   aws ssm get-parameter \
     --name "/github/personal-access-token" \
     --with-decryption \
     --query "Parameter.Value" \
     --output text
   ```

**Security Notes**:
- Never commit GitHub tokens to repository
- Use SecureString type for encryption at rest
- Parameter Store automatically handles token retrieval in CI/CD

Update `terraform/environments/global/terraform.tfvars`:
```hcl
github_repo = "YOUR_USERNAME/dofs-project"
github_connection_arn = "arn:aws:codestar-connections:us-east-1:ACCOUNT:connection/CONNECTION_ID"
# OR leave empty to use SSM parameter
```

## 5. Deploy Environments

### Development Environment
```bash
cd terraform/environments/multi-env
terraform init
terraform workspace new dev
terraform apply -var-file="dev.tfvars"
```

### Staging Environment
```bash
terraform workspace new staging
terraform apply -var-file="staging.tfvars"
```

### Production Environment
Production deploys automatically via CI/CD when you push to `main` branch.

## 6. Verify Installation

Test each environment:
```bash
# Get API URLs
terraform workspace select dev
API_URL=$(terraform output -raw api_gateway_url)

# Test API
curl -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "test-customer",
    "items": [{"product_id": "widget-123", "quantity": 2}]
  }'
```

## 7. CI/CD Pipeline Setup

The CI/CD pipelines are automatically created by the global infrastructure:

- **Non-Prod Pipeline**: `develop` branch → dev + staging environments  
- **Prod Pipeline**: `main` branch → production (with manual approval)

### Activate GitHub Webhooks
1. Push any change to `develop` branch to trigger non-prod pipeline
2. Push/merge to `main` branch to trigger prod pipeline

## Environment Management

### Adding New Environments
1. Create `{env}.tfvars` file in `terraform/environments/multi-env/`
2. Create workspace: `terraform workspace new {env}`
3. Deploy: `terraform apply -var-file="{env}.tfvars"`

### Destroying Environments
```bash
# Destroy specific environment
terraform workspace select {env}
terraform destroy -var-file="{env}.tfvars"

# Destroy global infrastructure (CAUTION: destroys CI/CD and state management)
cd ../global
# First remove state management from tracking (if permanent shutdown)
terraform state rm aws_s3_bucket.terraform_state
terraform state rm aws_dynamodb_table.terraform_locks
terraform destroy
```

## Testing

Run environment-specific tests:
```bash
# Development stress test
./stress-test.sh

# Staging test
./staging-test.sh

# Production test
./prod-test.sh
```

## Troubleshooting

### Common Issues

**"Backend configuration changed"**
- Run `terraform init -reconfigure`

**"Workspace already exists"**
- Run `terraform workspace select {env}` instead of `new`

**"Access denied" errors**
- Verify AWS profile and permissions
- Check IAM roles created by global infrastructure

**Pipeline not triggering**
- Verify GitHub connection in CodeStar console
- Check webhook configuration in repository settings

**GitHub authentication errors**
- Verify token is stored in Parameter Store: `/github/personal-access-token`
- Ensure token has `repo` permissions
- Check token hasn't expired (GitHub PATs have expiration dates)
- Test token manually:
  ```bash
  # Should return your user info
  curl -H "Authorization: token $(aws ssm get-parameter --name /github/personal-access-token --with-decryption --query Parameter.Value --output text)" https://api.github.com/user
  ```

### Getting Help

- Check AWS CodePipeline console for build status
- Review CloudWatch logs for Lambda function errors  
- Use `terraform plan` before `apply` to preview changes
- Check `docs/ARCHITECTURE_DIAGRAM.md` for system overview

## Clean Shutdown Process

When permanently shutting down the project:

1. **Destroy all application environments**:
   ```bash
   cd terraform/environments/multi-env
   for env in dev staging prod; do
     terraform workspace select $env
     terraform destroy -var-file="$env.tfvars" -auto-approve
   done
   ```

2. **Remove state management from tracking**:
   ```bash
   cd ../global
   terraform state rm aws_s3_bucket.terraform_state
   terraform state rm aws_dynamodb_table.terraform_locks
   ```

3. **Destroy global infrastructure**:
   ```bash
   terraform destroy -auto-approve
   ```

This ensures the S3 bucket containing state files isn't deleted before Terraform finishes the destroy process.