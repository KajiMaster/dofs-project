# Project Assignment: Distributed Order Fulfillment System (DOFS) with CI/CDObjective

## Design, implement, and deploy a production-grade event-driven serverless architecture using AWS services and Terraform. Build an automated CI/CD pipeline using AWS CodePipeline to manage deployments to a DEV environment.

# Architecture Overview

API Gateway --> Lambda (API Handler)
|
v
Step Function Orchestrator
|
+-------------------+------------------------+
|                   |                        |
v                   v                        v

Validate Lambda --> DynamoDB (orders) --> SQS --> Fulfillment Lambda
|
v
DynamoDB update + DLQ

Functional Components

1. API Handler (Lambda)
REST endpoint via API Gateway
Accepts POST /order requests with JSON payload
Triggers Step Function execution
2. Step Function (Orchestrator)
Validate Order Lambda
Store Order Lambda: Save to DynamoDB (orders)
Push to SQS queue for fulfillment
3. Fulfillment Lambda
Triggered by SQS
Processes order (simulated with 70% success rate)
Updates orders table status: FULFILLED or FAILED
Unsuccessful messages after retries → DLQ
Log all operations with structured JSON
4. DLQ &amp; Alerting
Messages failing &gt; maxReceiveCount go to DLQ
Write DLQ messages to failed_orders DynamoDB table
Optional: SNS Alert if DLQ depth &gt; threshold

Terraform Infrastructure (Modules Required): Create Terraform code to provision:

Core AWS Services
API Gateway + Lambda Integration

Step Functions with tasks (via AWS SDK integration or Lambda)
DynamoDB tables:

orders (PK: order_id)
failed_orders
SQS queues: order_queue, order_dlq
Fulfillment Lambda triggered by SQS
CI/CD Pipeline
AWS CodePipeline (Terraform-defined) for:

Source: GitHub or CodeCommit
Build: CodeBuild to run terraform plan and terraform apply to DEV
Manual approval stage (optional)
Terraform Files for Pipeline Setup

IAM roles for CodePipeline and CodeBuild
S3 bucket for storing Terraform state
Enable backend config for remote state
Folder Structure

dofs-project/
├── lambdas/
│ ├── api_handler/
│ ├── validator/
│ ├── order_storage/
│ └── fulfill_order/
├── terraform/
│ ├── main.tf
│ ├── variables.tf
│ ├── outputs.tf
│ ├── backend.tf
│ ├── modules/
│ │ ├── api_gateway/
│ │ ├── lambdas/
│ │ ├── dynamodb/
│ │ ├── sqs/
│ │ ├── stepfunctions/
│ │ └── monitoring/
│ ├── cicd/
│ │ ├── codebuild.tf
│ │ ├── codepipeline.tf
│ │ └── iam_roles.tf
├── buildspec.yml # CodeBuild spec
├── .github/
│ └── workflows/
│ └── ci.yml (optional GitHub Actions)
└── README.md

Deliverables

Fully functional end-to-end system
Well-documented Terraform modules
Testing guide for:

Success scenario
Failure and DLQ handling
CI/CD system (Terraform + CodePipeline)
README with:

Prerequisites
Setup instructions
Troubleshooting
Pipeline explanation

Deliverables for Submission (email back with links &amp; attachments)
Source Code Repositories: Provide URLs to the GitHub repositories for each service
Documentation and Diagrams in a single PDF that includes a code repository link
Keep explanations clear and concise.
Video demo of your Solution journey - from requirements, through key assumptions &amp; work
completed, to the final solution and how it solves the problems. You can use Loom -
https://www.loom.com