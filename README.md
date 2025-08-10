# Distributed Order Fulfillment System (DOFS)

A production-ready, event-driven serverless architecture built on AWS using Terraform. This system demonstrates modern cloud-native patterns with automated CI/CD pipelines, multi-environment deployments, and comprehensive error handling.

## Architecture Overview

```
API Gateway → Lambda (API Handler) → Step Functions Orchestrator
                ↓                           ↓
            Validation              Order Storage (DynamoDB)
                ↓                           ↓
            SQS Queue ←→ Fulfillment Lambda → DLQ + Failed Orders
```

### Core Components

- **API Gateway**: REST endpoint for order submission
- **Lambda Functions**: API handling, validation, storage, and fulfillment
- **Step Functions**: Workflow orchestration with error handling
- **DynamoDB**: Order storage and failed order tracking
- **SQS**: Message queuing with dead letter queue
- **CodePipeline**: Automated CI/CD with GitFlow workflow

### Key Features

- ✅ **Multi-Environment Support**: dev, staging, production
- ✅ **GitFlow CI/CD**: develop → staging, main → production with approval
- ✅ **Error Handling**: DLQ processing and failed order tracking
- ✅ **Infrastructure as Code**: Complete Terraform automation
- ✅ **Security**: IAM roles, encrypted storage, secure secrets management
- ✅ **Monitoring**: CloudWatch logging and structured JSON output

## Installation

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- GitHub account with repository access
- GitHub Personal Access Token with repo permissions

### Step 1: Repository Setup

1. **Fork or clone this repository**:
   ```bash
   git clone https://github.com/KajiMaster/dofs-project.git
   cd dofs-project
   ```

2. **Update repository configuration**:
   Edit `terraform/environments/global/terraform.tfvars`:
   ```hcl
   github_repo = "your-username/your-repo-name"
   ```

### Step 2: AWS Configuration

1. **Configure GitHub Personal Access Token**:
   ```bash
   aws ssm put-parameter \
     --region us-east-1 \
     --name "/github/personal-access-token" \
     --value "ghp_your_github_token_here" \
     --type "SecureString" \
     --description "GitHub PAT for CI/CD pipelines"
   ```

2. **Deploy global infrastructure** (bootstrap + CI/CD):
   ```bash
   cd terraform/environments/global
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy application infrastructure**:
   ```bash
   cd ../multi-env
   terraform init
   terraform workspace new dev
   terraform plan -var-file="dev.tfvars"
   terraform apply -var-file="dev.tfvars"
   ```

### Step 3: Pipeline Setup

1. **Push code to trigger pipeline**:
   ```bash
   git checkout develop
   git push origin develop  # Triggers non-prod pipeline
   ```

2. **For production deployment**:
   ```bash
   git checkout main
   git merge develop
   git push origin main     # Triggers prod pipeline (requires manual approval)
   ```

## Usage

### Testing the API

Use the included test script:
```bash
./test-api.sh
```

Or manually test with curl:
```bash
curl -X POST https://your-api-gateway-url/dev/order \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-12345",
    "items": [
      {"product_id": "prod-widget-001", "quantity": 2}
    ]
  }'
```

### Monitoring

- **API Gateway**: CloudWatch metrics and logs
- **Lambda Functions**: CloudWatch logs with structured JSON
- **Step Functions**: Execution history and flow visualization
- **DynamoDB**: Order status and failed order tracking
- **CodePipeline**: Build history and deployment status

## Project Structure

```
dofs-project/
├── terraform/
│   ├── environments/
│   │   ├── global/              # Bootstrap + CI/CD infrastructure
│   │   │   ├── main.tf          # S3 backend, DynamoDB locks
│   │   │   ├── cicd.tf          # CodePipeline, CodeBuild
│   │   │   └── terraform.tfvars # Global configuration
│   │   └── multi-env/           # Application infrastructure
│   │       ├── main.tf          # Calls all modules
│   │       ├── dev.tfvars       # Development settings
│   │       ├── staging.tfvars   # Staging settings
│   │       └── prod.tfvars      # Production settings
│   └── modules/
│       ├── api_gateway/         # API Gateway configuration
│       ├── lambdas/             # Lambda functions and source
│       ├── dynamodb/            # DynamoDB tables
│       ├── sqs/                 # SQS queues and DLQ
│       └── stepfunctions/       # Workflow orchestration
├── buildspec-nonprod.yml       # Non-prod build configuration
├── buildspec-prod.yml           # Production build configuration
└── test-api.sh                 # API testing script
```

## GitFlow Workflow

### Branch Strategy
- **`develop`**: Development branch → triggers dev + staging deployment
- **`main`**: Production branch → triggers production deployment (with approval)
- **`feature/*`**: Feature branches → create PRs to develop

### Typical Development Flow
```bash
# Feature development
git checkout develop
git checkout -b feature/new-feature
git push origin feature/new-feature
# Create PR: feature/new-feature → develop

# Deploy to dev/staging
git checkout develop
git merge feature/new-feature
git push origin develop  # Auto-deploys to dev → staging

# Deploy to production
git checkout main
git merge develop
git push origin main     # Triggers prod pipeline (manual approval required)
```

## Configuration

### Environment Variables

Each environment can be customized via `.tfvars` files:

```hcl
# dev.tfvars
project_name = "dofs"
environment = "dev"
lambda_memory_size = 128
fulfillment_success_rate = 0.7

# prod.tfvars  
project_name = "dofs"
environment = "prod"
lambda_memory_size = 256
fulfillment_success_rate = 0.9
```

### AWS Resources Created

| Service | Resource | Purpose |
|---------|----------|---------|
| **Global** | S3 Bucket | Terraform state storage |
| | DynamoDB Table | Terraform state locking |
| | CodeCommit/GitHub | Source code repository |
| | CodePipeline | CI/CD automation |
| | CodeBuild | Build and deployment |
| **Per Environment** | API Gateway | REST API endpoint |
| | Lambda Functions | Business logic (4 functions) |
| | Step Functions | Workflow orchestration |
| | DynamoDB Tables | Order storage (2 tables) |
| | SQS Queues | Message processing (2 queues) |

## Cost Estimation

### Monthly Costs (estimated)
- **Global Infrastructure**: ~$3/month (CI/CD pipeline)
- **Per Environment**: ~$5-15/month (depending on usage)
  - API Gateway: $3.50/million requests
  - Lambda: $0.20/million requests
  - DynamoDB: Pay-per-request pricing
  - Step Functions: $25/million transitions

## Security

- **IAM Roles**: Least-privilege access for all services
- **Encryption**: At-rest encryption for DynamoDB and S3
- **Secrets Management**: GitHub tokens stored in AWS Parameter Store
- **VPC**: Can be deployed within VPC for additional isolation
- **Access Logging**: All API calls logged to CloudWatch

## Support & Troubleshooting

### Common Issues

1. **GitHub Token Issues**: Verify token is stored correctly in Parameter Store
2. **Terraform State Conflicts**: Check DynamoDB locks table
3. **Pipeline Failures**: Review CodeBuild logs in CloudWatch
4. **Lambda Errors**: Check CloudWatch logs for each function

### Development Commands

```bash
# Terraform operations
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
terraform workspace list

# Testing
./test-api.sh
aws logs tail /aws/lambda/dofs-dev-api-handler --follow
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request to `develop`

## License

This project is provided as-is for educational and demonstration purposes.

---

**Built with AWS Serverless Architecture + Terraform + GitFlow CI/CD**# Test automatic pipeline trigger
