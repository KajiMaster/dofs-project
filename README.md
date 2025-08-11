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

1. **Create dedicated AWS profile for this project** (recommended to avoid conflicts):
   ```bash
   # Create dofs-project profile with us-east-1 region
   aws configure set region us-east-1 --profile dofs-project
   
   # Copy credentials from your default profile (or set them directly)
   aws configure set aws_access_key_id YOUR_ACCESS_KEY --profile dofs-project
   aws configure set aws_secret_access_key YOUR_SECRET_KEY --profile dofs-project
   
   # Set environment variable to use this profile
   export AWS_PROFILE=dofs-project
   ```

2. **Configure GitHub Personal Access Token**:
   ```bash
   aws ssm put-parameter \
     --region us-east-1 \
     --name "/github/personal-access-token" \
     --value "ghp_your_github_token_here" \
     --type "SecureString" \
     --description "GitHub PAT for CI/CD pipelines"
   ```

3. **Deploy global infrastructure** (bootstrap + CI/CD):
   ```bash
   cd terraform/environments/global
   terraform init
   terraform plan
   terraform apply
   ```

4. **Deploy application infrastructure**:
   ```bash
   cd ../multi-env
   terraform init
   terraform workspace new dev
   terraform plan -var-file="dev.tfvars"
   terraform apply -var-file="dev.tfvars"
   ```

### Step 3: Pipeline Setup

**Manual Pipeline Triggers** (CodeStar webhooks require manual triggering):

1. **Deploy to dev/staging**:
   ```bash
   # After pushing code to develop branch
   git checkout develop
   git push origin develop
   
   # Manually trigger the pipeline
   aws codepipeline start-pipeline-execution --region us-east-1 --name dofs-nonprod-pipeline
   ```

2. **Deploy to production**:
   ```bash
   # After pushing/merging to main branch  
   git checkout main
   git merge develop
   git push origin main
   
   # Manually trigger the pipeline
   aws codepipeline start-pipeline-execution --region us-east-1 --name dofs-prod-pipeline
   ```

3. **Monitor pipeline status**:
   ```bash
   # Check current pipeline state
   aws codepipeline get-pipeline-state --region us-east-1 --name dofs-nonprod-pipeline
   
   # View execution history
   aws codepipeline list-pipeline-executions --region us-east-1 --pipeline-name dofs-nonprod-pipeline --max-items 5
   ```

## Usage

### Getting the API URL

After deployment, get your API Gateway URL:
```bash
export AWS_PROFILE=dofs-project
cd terraform/environments/multi-env
terraform output api_gateway_url
```

### Testing the API

**Quick Test** - Use the included test script:
```bash
export AWS_PROFILE=dofs-project  # Use your dofs-project profile
./test-api.sh
```

**Manual Testing** - Replace `YOUR_API_URL` with your actual API Gateway URL:
```bash
# Valid order (should succeed)
curl -X POST YOUR_API_URL/order \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust-12345",
    "items": [
      {"product_id": "prod-widget-001", "quantity": 2}
    ]
  }'

# Expected response:
# {
#   "message": "Order received and processing started",
#   "order_id": "uuid-here",
#   "status": "processing",
#   "execution_arn": "arn:aws:states:..."
# }
```

### API Validation

The system has **two-tier validation**:

1. **API Gateway Validation** (first layer):
   - Validates JSON format and required fields
   - Returns: `{"message": "Invalid request body"}` for format errors
   
2. **Lambda Validation** (business logic):  
   - Validates business rules and environment configuration
   - Returns specific error messages like: `{"error": "Step Function ARN not configured"}`

**Common validation errors**:
```bash
# Missing required fields → API Gateway blocks
curl -X POST YOUR_API_URL/order \
  -d '{"items": [{"product_id": "test", "quantity": 1}]}'
# Response: {"message": "Invalid request body"}

# Empty items array → Lambda validates  
curl -X POST YOUR_API_URL/order \
  -d '{"customer_id": "test", "items": []}'
# Response: {"error": "items must be a non-empty array"}

# Invalid quantity → API Gateway blocks
curl -X POST YOUR_API_URL/order \
  -d '{"customer_id": "test", "items": [{"product_id": "test", "quantity": 0}]}'
# Response: {"message": "Invalid request body"}
```

### Monitoring & Verification

**Check Order Processing**:
```bash
export AWS_PROFILE=dofs-project

# View order counts
aws dynamodb scan --table-name dofs-dev-orders --select COUNT
aws dynamodb scan --table-name dofs-dev-failed-orders --select COUNT

# Check order status breakdown
aws dynamodb scan --table-name dofs-dev-orders \
  --projection-expression "#s" \
  --expression-attribute-names '{"#s":"status"}' | \
  jq '.Items[].status.S' | sort | uniq -c

# View failed orders
aws dynamodb scan --table-name dofs-dev-failed-orders | jq '.Items'
```

**Check SQS Queues**:
```bash
# Check message counts
aws sqs get-queue-attributes \
  --queue-url https://queue.amazonaws.com/YOUR-ACCOUNT/dofs-dev-order-queue \
  --attribute-names ApproximateNumberOfMessages

aws sqs get-queue-attributes \
  --queue-url https://queue.amazonaws.com/YOUR-ACCOUNT/dofs-dev-order-dlq \
  --attribute-names ApproximateNumberOfMessages
```

**CloudWatch Logs**:
```bash
# Lambda function logs
aws logs describe-log-groups | jq '.logGroups[] | select(.logGroupName | contains("dofs"))'

# Step Function execution logs  
aws logs describe-log-groups | jq '.logGroups[] | select(.logGroupName | contains("stepfunctions"))'
```

**System Health Indicators**:
- **Success Rate**: ~70% orders FULFILLED, ~30% FAILED (as designed by `fulfillment_success_rate = 0.7`)
- **Queue Status**: Both main queue and DLQ should be empty (0 messages) when idle
- **Failed Orders**: Failed orders appear in both `orders` table (status: FAILED) and `failed_orders` table
- **Order States**: Orders progress through PROCESSING → FULFILLED/FAILED
- **Error Handling**: Failed fulfillments trigger DLQ processing and failed order table updates

### System Behavior

**Order Processing Flow**:
1. **API Gateway** receives POST to `/order` endpoint
2. **API Handler Lambda** validates input and starts Step Function
3. **Step Functions** orchestrates: Validation → Storage → SQS queuing  
4. **SQS Queue** triggers Fulfillment Lambda
5. **Fulfillment Lambda** simulates processing (70% success rate)
6. **Success**: Updates order status to FULFILLED
7. **Failure**: Moves order to failed_orders table, marks as FAILED

**Validated Behaviors** (tested):
- ✅ **API Validation**: Two-tier validation (API Gateway + Lambda)
- ✅ **Order Processing**: Complete end-to-end flow
- ✅ **Success/Failure Simulation**: ~70/30 split working correctly
- ✅ **Error Handling**: Failed orders properly tracked and stored
- ✅ **SQS Processing**: Messages processed without accumulation in DLQ
- ✅ **Environment Isolation**: AWS profile prevents region conflicts

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
- **`develop`**: Development branch → manual trigger for dev + staging deployment  
- **`main`**: Production branch → manual trigger for production deployment (with approval)
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
git push origin develop
# Manually trigger: aws codepipeline start-pipeline-execution --region us-east-1 --name dofs-nonprod-pipeline

# Deploy to production  
git checkout main
git merge develop
git push origin main
# Manually trigger: aws codepipeline start-pipeline-execution --region us-east-1 --name dofs-prod-pipeline
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
# Set profile for all operations
export AWS_PROFILE=dofs-project

# Terraform operations
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
terraform workspace list
terraform output  # Get API Gateway URL and other outputs

# Testing and monitoring
./test-api.sh
aws dynamodb scan --table-name dofs-dev-orders --select COUNT
aws dynamodb scan --table-name dofs-dev-failed-orders --select COUNT

# CloudWatch logs (replace with actual log stream names)
aws logs describe-log-streams --log-group-name /aws/lambda/dofs-dev-api-handler
aws logs describe-log-streams --log-group-name /aws/lambda/dofs-dev-fulfill-order
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

**Built with AWS Serverless Architecture + Terraform + GitFlow CI/CD**
