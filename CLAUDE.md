# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Distributed Order Fulfillment System (DOFS) project - an event-driven serverless architecture assignment using AWS services and Terraform. The project implements a complete order processing system with the following architecture:

**Flow**: API Gateway → Lambda (API Handler) → Step Function Orchestrator → [Validate Lambda, Store Order Lambda, SQS Queue] → Fulfillment Lambda → DynamoDB

## Architecture Components

### Core Services
- **API Handler Lambda**: REST endpoint via API Gateway accepting POST /order requests
- **Step Function Orchestrator**: Coordinates the order processing workflow
- **Validation Lambda**: Validates incoming orders
- **Order Storage Lambda**: Saves orders to DynamoDB
- **Fulfillment Lambda**: Processes orders (70% success rate simulation)
- **DynamoDB Tables**: `orders` (PK: order_id) and `failed_orders`
- **SQS**: `order_queue` and `order_dlq` for message processing and dead letter handling

### Infrastructure
- All infrastructure defined in Terraform modules
- CI/CD pipeline using AWS CodePipeline and CodeBuild
- Remote state stored in S3 backend

## Expected Project Structure

```
dofs-project/
├── lambdas/
│   ├── api_handler/
│   ├── validator/
│   ├── order_storage/
│   └── fulfill_order/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   ├── modules/
│   │   ├── api_gateway/
│   │   ├── lambdas/
│   │   ├── dynamodb/
│   │   ├── sqs/
│   │   ├── stepfunctions/
│   │   └── monitoring/
│   └── cicd/
│       ├── codebuild.tf
│       ├── codepipeline.tf
│       └── iam_roles.tf
├── buildspec.yml
└── README.md
```

## Development Commands

Since this is a new project with only the requirements document, standard commands will be:

**Terraform Operations:**
```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform destroy
```

**Lambda Development:**
- Lambda functions will be developed in their respective directories under `lambdas/`
- Each Lambda should include deployment packages (zip files) or use Terraform's archive_file data source

**CI/CD:**
- CodePipeline will be triggered from source control (GitHub/CodeCommit)
- CodeBuild uses `buildspec.yml` for build specifications

## Key Implementation Notes

- All Lambda functions must log operations with structured JSON
- Fulfillment Lambda simulates 70% success rate for order processing
- Failed messages after retries go to DLQ and are written to `failed_orders` table
- Step Functions orchestrate the entire workflow using AWS SDK integrations
- Infrastructure uses modular Terraform design for reusability
- Pipeline includes manual approval stage (optional)

## Testing Strategy

The system requires testing for:
1. **Success Scenario**: Complete order flow from API to fulfillment
2. **Failure Handling**: DLQ processing and failed order storage
3. **CI/CD Pipeline**: Terraform plan/apply automation

## Current State

**Status**: Project initialization phase - only requirements document exists
**Next Steps**: Implement the folder structure and begin with Terraform infrastructure modules