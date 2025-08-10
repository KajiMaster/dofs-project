# DOFS System Architecture - Visual Documentation

This document provides detailed visual representations of the DOFS system architecture for whiteboard sessions, system design discussions, and onboarding.

## 1. High-Level System Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Client    │───▶│   API Gateway    │───▶│  Lambda (API)   │
│                 │    │                  │    │                 │
│ curl/browser    │    │ REST /order      │    │ Input validation│
│                 │    │ JSON validation  │    │ Step Functions  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudWatch    │◀───│  Step Functions  │───▶│ Lambda (Validator)
│                 │    │                  │    │                 │
│ Execution logs  │    │ Order Processing │    │ Business Rules  │
│ Error tracking  │    │ State Machine    │    │ Customer/Items  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                         │
                                │ Success                 │ Failed
                                ▼                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│Lambda (Storage) │    │    DynamoDB      │    │  Error States   │
│                 │───▶│                  │    │                 │
│ Order Storage   │    │ orders table     │    │ ValidationFailed│
│ Metadata        │    │ PK: order_id     │    │ StorageFailed   │
└─────────────────┘    └──────────────────┘    │ QueueFailed     │
         │                                      └─────────────────┘
         │ Success
         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SQS Queue     │───▶│Lambda (Fulfill)  │───▶│    DynamoDB     │
│                 │    │                  │    │                 │
│ order-queue     │    │ 70% Success Rate │    │ Status Updates  │
│ Message Body    │    │ Random Success   │    │ FULFILLED/FAILED│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │ Failed (30%)           │
         │                       ▼                        │
         │              ┌─────────────────┐               │
         │              │   SQS DLQ       │               │
         │              │                 │               │
         │              │ order-dlq       │               │
         │              │ Failed Messages │               │
         │              └─────────────────┘               │
         │                       │                        │
         │                       ▼                        │
         │              ┌─────────────────┐               │
         │              │Lambda (DLQ)     │               │
         │              │                 │               │
         │              │ DLQ Handler     │               │
         │              │ Failed Orders   │               │
         │              └─────────────────┘               │
         │                       │                        │
         │                       ▼                        │
         │              ┌─────────────────┐               │
         └─────────────▶│    DynamoDB     │◀──────────────┘
                        │                 │
                        │failed_orders    │
                        │PK: order_id     │
                        └─────────────────┘
```

## 2. Detailed Component Interaction Map

### A. Request Processing Flow
```
User Request
     │
     ▼
┌─────────────────────────────────────────────┐
│           API Gateway                       │
│                                             │
│ ┌─────────────────┐ ┌─────────────────────┐ │
│ │ Input Validator │ │   Method: POST      │ │
│ │                 │ │   Path: /order      │ │
│ │ - JSON Schema   │ │   Headers: CORS     │ │
│ │ - Required      │ │   Integration:      │ │
│ │   Fields        │ │   AWS_PROXY         │ │
│ └─────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────┘
     │ Valid JSON
     ▼
┌─────────────────────────────────────────────┐
│         Lambda: API Handler                 │
│                                             │
│ ┌─────────────────┐ ┌─────────────────────┐ │
│ │ Business Logic  │ │   Environment       │ │
│ │                 │ │                     │ │
│ │ - Generate UUID │ │ - STEP_FUNCTION_ARN │ │
│ │ - Add Timestamp │ │ - TABLE_NAMES       │ │
│ │ - Create Order  │ │ - PROJECT_NAME      │ │
│ │   Object        │ │ - ENVIRONMENT       │ │
│ └─────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────┘
     │ Start Execution
     ▼
┌─────────────────────────────────────────────┐
│        Step Functions State Machine        │
│                                             │
│  States and Transitions:                    │
│  ┌──────────────────────────────────────┐   │
│  │ 1. ValidateOrder (Task)              │   │
│  │    ├─Success─▶ CheckValidation       │   │
│  │    └─Error───▶ ValidationFailed      │   │
│  │                                      │   │
│  │ 2. CheckValidation (Choice)          │   │
│  │    ├─PASSED──▶ StoreOrder            │   │
│  │    └─Default─▶ ValidationFailed      │   │
│  │                                      │   │
│  │ 3. StoreOrder (Task)                 │   │
│  │    ├─Success─▶ CheckStorage          │   │
│  │    └─Error───▶ StorageFailed         │   │
│  │                                      │   │
│  │ 4. CheckStorage (Choice)             │   │
│  │    ├─SUCCESS─▶ SendToQueue           │   │
│  │    └─Default─▶ StorageFailed         │   │
│  │                                      │   │
│  │ 5. SendToQueue (SQS Integration)     │   │
│  │    ├─Success─▶ QueueSent             │   │
│  │    └─Error───▶ QueueFailed           │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### B. Data Flow and State Management
```
┌─────────────────────────────────────────────────────────────────┐
│                    Data Flow Diagram                           │
│                                                                 │
│ Input Data Structure:                                           │
│ {                                                               │
│   "order": {                                                    │
│     "order_id": "uuid",                                         │
│     "customer_id": "string",                                    │
│     "items": [{"product_id": "string", "quantity": number}],    │
│     "timestamp": "ISO-8601"                                     │
│   },                                                            │
│   "timestamp": "ISO-8601",                                      │
│   "source": "api-gateway"                                       │
│ }                                                               │
│                                                                 │
│ ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│ │ Validation  │───▶│  Storage    │───▶│   Queue     │         │
│ │             │    │             │    │             │         │
│ │ + Enriched  │    │ + Metadata  │    │ Same Object │         │
│ │   with      │    │   - status  │    │ for Async   │         │
│ │   validation│    │   - created │    │ Processing  │         │
│ │   result    │    │   - updated │    │             │         │
│ │             │    │   - retry   │    │             │         │
│ └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Lambda Function Details

### Function Architecture Map
```
┌────────────────────────────────────────────────────────────────┐
│                    Lambda Functions                           │
│                                                                │
│ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│ │   API Handler   │  │   Validator     │  │ Order Storage   │ │
│ │                 │  │                 │  │                 │ │
│ │ Role:           │  │ Role:           │  │ Role:           │ │
│ │ - Input Validation│ │ - Business Rules│  │ - Data Persist  │ │
│ │ - Step Function │  │ - Format Check  │  │ - Metadata Add  │ │
│ │   Orchestration │  │ - Quantity Limit│  │ - Duplicate     │ │
│ │                 │  │   (max 100)     │  │   Prevention    │ │
│ │ Permissions:    │  │                 │  │                 │ │
│ │ - states:Start  │  │ Permissions:    │  │ Permissions:    │ │
│ │   Execution     │  │ - logs:*        │  │ - dynamodb:*    │ │
│ │ - dynamodb:*    │  │                 │  │ - logs:*        │ │
│ │ - logs:*        │  │                 │  │                 │ │
│ └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                │
│ ┌─────────────────┐  ┌─────────────────┐                      │
│ │ Fulfillment     │  │  DLQ Handler    │                      │
│ │                 │  │                 │                      │
│ │ Role:           │  │ Role:           │                      │
│ │ - Process Orders│  │ - Process Failed│                      │
│ │ - 70% Success   │  │   Messages      │                      │
│ │   Simulation    │  │ - Store in      │                      │
│ │ - Status Update │  │   Failed Table  │                      │
│ │                 │  │                 │                      │
│ │ Permissions:    │  │ Permissions:    │                      │
│ │ - dynamodb:*    │  │ - dynamodb:Put  │                      │
│ │ - sqs:*         │  │ - sqs:*         │                      │
│ │ - logs:*        │  │ - logs:*        │                      │
│ └─────────────────┘  └─────────────────┘                      │
└────────────────────────────────────────────────────────────────┘
```

## 4. Database Schema and Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                     DynamoDB Tables                            │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                 orders Table                                │ │
│ │                                                             │ │
│ │ Primary Key: order_id (String)                              │ │
│ │                                                             │ │
│ │ Attributes:                                                 │ │
│ │ ├─ order_id         (PK) - UUID                             │ │
│ │ ├─ customer_id      (String) - Customer identifier          │ │
│ │ ├─ items            (List) - Array of order items           │ │
│ │ │   └─ [{                                                   │ │
│ │ │       "product_id": "string",                             │ │
│ │ │       "quantity": number                                  │ │
│ │ │     }]                                                    │ │
│ │ ├─ status           (String) - PROCESSING|FULFILLED|FAILED  │ │
│ │ ├─ timestamp        (String) - ISO-8601 creation time      │ │
│ │ ├─ created_at       (String) - ISO-8601                    │ │
│ │ ├─ updated_at       (String) - ISO-8601                    │ │
│ │ ├─ fulfilled_at     (String) - ISO-8601 (if successful)    │ │
│ │ ├─ failed_at        (String) - ISO-8601 (if failed)        │ │
│ │ ├─ retry_count      (Number) - Retry attempts              │ │
│ │ └─ total_quantity   (Number) - Sum of all item quantities  │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │              failed_orders Table                           │ │
│ │                                                             │ │
│ │ Primary Key: order_id (String)                              │ │
│ │                                                             │ │
│ │ Attributes:                                                 │ │
│ │ ├─ order_id         (PK) - UUID (same as original)         │ │
│ │ ├─ original_order_id (String) - Reference to orders table   │ │
│ │ ├─ customer_id      (String) - Customer identifier          │ │
│ │ ├─ items            (List) - Array of order items           │ │
│ │ ├─ failure_reason   (String) - Why the order failed        │ │
│ │ ├─ failed_at        (String) - ISO-8601 failure time       │ │
│ │ ├─ retry_count      (Number) - Number of retry attempts    │ │
│ │ ├─ created_at       (String) - Original order creation     │ │
│ │ └─ updated_at       (String) - Last update time            │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 5. Message Queue Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  SQS Queue System                              │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                Main Order Queue                             │ │
│ │                                                             │ │
│ │ Queue: dofs-dev-order-queue                                 │ │
│ │                                                             │ │
│ │ Configuration:                                              │ │
│ │ ├─ Visibility Timeout: 30 seconds                          │ │
│ │ ├─ Message Retention: 14 days                              │ │
│ │ ├─ Max Receive Count: 3                                     │ │
│ │ ├─ Dead Letter Queue: dofs-dev-order-dlq                   │ │
│ │                                                             │ │
│ │ Message Format:                                             │ │
│ │ {                                                           │ │
│ │   "order": {                                                │ │
│ │     "order_id": "uuid",                                     │ │
│ │     "customer_id": "string",                                │ │
│ │     "items": [...],                                         │ │
│ │     "status": "PROCESSING",                                 │ │
│ │     "timestamp": "ISO-8601",                                │ │
│ │     "created_at": "ISO-8601"                                │ │
│ │   },                                                        │ │
│ │   "timestamp": "ISO-8601",                                  │ │
│ │   "source": "api-gateway"                                   │ │
│ │ }                                                           │ │
│ │                                                             │ │
│ │ Event Source Mapping:                                       │ │
│ │ ├─ Lambda Function: dofs-dev-fulfill-order                 │ │
│ │ ├─ Batch Size: 1                                           │ │
│ │ └─ Trigger: On message arrival                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                               │                               │
│                               │ Failed after 3 retries       │
│                               ▼                               │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                Dead Letter Queue                            │ │
│ │                                                             │ │
│ │ Queue: dofs-dev-order-dlq                                   │ │
│ │                                                             │ │
│ │ Configuration:                                              │ │
│ │ ├─ Message Retention: 14 days                              │ │
│ │ ├─ No Dead Letter Queue (terminal)                         │ │
│ │                                                             │ │
│ │ Event Source Mapping:                                       │ │
│ │ ├─ Lambda Function: dofs-dev-dlq-handler                   │ │
│ │ ├─ Batch Size: 10                                          │ │
│ │ └─ Trigger: On message arrival                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 6. CI/CD Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CI/CD Architecture                          │
│                                                                 │
│ ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│ │     GitHub      │───▶│   CodeStar      │───▶│ CodePipeline │ │
│ │                 │    │   Connection    │    │              │ │
│ │ - Source Code   │    │                 │    │ Non-Prod:    │ │
│ │ - Branch: dev   │    │ - Webhook       │    │ ├─ Source    │ │
│ │ - Terraform     │    │ - Events        │    │ ├─ Dev       │ │
│ │ - Lambda Code   │    │                 │    │ └─ Staging   │ │
│ │                 │    │                 │    │              │ │
│ └─────────────────┘    └─────────────────┘    │ Production:  │ │
│                                               │ ├─ Source    │ │
│                                               │ ├─ Approval  │ │
│                                               │ └─ Prod      │ │
│                                               └──────────────┘ │
│                                                       │        │
│                                                       ▼        │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                   CodeBuild                                 │ │
│ │                                                             │ │
│ │ Build Specification (buildspec-nonprod.yml):                │ │
│ │ ┌─────────────────────────────────────────────────────────┐ │ │
│ │ │ phases:                                                 │ │ │
│ │ │   install:                                              │ │ │
│ │ │     - Install Terraform via HashiCorp APT repo         │ │ │
│ │ │   pre_build:                                            │ │ │
│ │ │     - terraform init                                    │ │ │
│ │ │     - terraform workspace select $TF_WORKSPACE         │ │ │
│ │ │   build:                                                │ │ │
│ │ │     - terraform plan -var-file=$TF_VAR_FILE            │ │ │
│ │ │     - terraform apply -var-file=$TF_VAR_FILE           │ │ │
│ │ └─────────────────────────────────────────────────────────┘ │ │
│ │                                                             │ │
│ │ Environment Variables:                                      │ │
│ │ ├─ TF_WORKSPACE: dev/staging/prod                           │ │
│ │ ├─ TF_VAR_FILE: environment-specific tfvars                 │ │
│ │ └─ TF_IN_AUTOMATION: true                                   │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 7. Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Error Handling                             │
│                                                                 │
│                    Request Flow                                 │
│                         │                                       │
│            ┌────────────┴────────────┐                          │
│            │                         │                          │
│    ┌───────▼────────┐      ┌─────────▼────────┐                │
│    │ API Gateway    │      │ Lambda Timeout   │                │
│    │ Validation     │      │ Network Error    │                │
│    │                │      │ Runtime Error    │                │
│    │ Invalid JSON   │      │                  │                │
│    │ Missing Fields │      │                  │                │
│    │ Schema Errors  │      │                  │                │
│    └───────┬────────┘      └─────────┬────────┘                │
│            │                         │                          │
│            ▼                         ▼                          │
│    ┌───────────────┐      ┌─────────────────────────────────┐   │
│    │ HTTP 400      │      │     Step Functions             │   │
│    │ "Invalid      │      │                                │   │
│    │  request      │      │ Retry Configuration:           │   │
│    │  body"        │      │ ├─ MaxAttempts: 3               │   │
│    │               │      │ ├─ IntervalSeconds: 1           │   │
│    │               │      │ └─ BackoffRate: 2               │   │
│    └───────────────┘      │                                │   │
│                           │ Catch Configuration:           │   │
│                           │ ├─ States.TaskFailed           │   │
│                           │ └─ Route to Error States       │   │
│                           └─────────────────────────────────┘   │
│                                           │                     │
│                                           ▼                     │
│          ┌────────────────────────────────────────────────┐     │
│          │               Error States                     │     │
│          │                                                │     │
│          │ ValidationFailed:                              │     │
│          │ ├─ Business rule violations                    │     │
│          │ ├─ Format errors                               │     │
│          │ └─ Customer/item validation failures           │     │
│          │                                                │     │
│          │ StorageFailed:                                 │     │
│          │ ├─ DynamoDB errors                             │     │
│          │ ├─ Duplicate key violations                    │     │
│          │ └─ Permission issues                           │     │
│          │                                                │     │
│          │ QueueFailed:                                   │     │
│          │ ├─ SQS unavailable                             │     │
│          │ ├─ Permission errors                           │     │
│          │ └─ Message format issues                       │     │
│          └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

## 8. Monitoring and Observability

```
┌─────────────────────────────────────────────────────────────────┐
│                  Monitoring Architecture                       │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                   CloudWatch Logs                          │ │
│ │                                                             │ │
│ │ Log Groups:                                                 │ │
│ │ ├─ /aws/lambda/dofs-dev-api-handler                        │ │
│ │ ├─ /aws/lambda/dofs-dev-validator                          │ │
│ │ ├─ /aws/lambda/dofs-dev-order-storage                      │ │
│ │ ├─ /aws/lambda/dofs-dev-fulfill-order                      │ │
│ │ ├─ /aws/lambda/dofs-dev-dlq-handler                        │ │
│ │ └─ /aws/stepfunctions/dofs-dev-order-processing            │ │
│ │                                                             │ │
│ │ Log Format (Structured JSON):                               │ │
│ │ {                                                           │ │
│ │   "timestamp": "ISO-8601",                                  │ │
│ │   "level": "INFO|WARN|ERROR",                               │ │
│ │   "message": "Human readable message",                      │ │
│ │   "order_id": "uuid",                                       │ │
│ │   "function": "function-name",                              │ │
│ │   "stage": "validation|storage|fulfillment"                 │ │
│ │ }                                                           │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                               │                               │
│                               ▼                               │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                CloudWatch Metrics                          │ │
│ │                                                             │ │
│ │ Built-in Metrics:                                           │ │
│ │ ├─ Lambda: Invocations, Duration, Errors, Throttles        │ │
│ │ ├─ API Gateway: Count, Latency, 4XX/5XX Errors            │ │
│ │ ├─ Step Functions: ExecutionsSucceeded, ExecutionsFailed   │ │
│ │ ├─ DynamoDB: ConsumedReadCapacity, ConsumedWriteCapacity   │ │
│ │ └─ SQS: NumberOfMessagesSent, NumberOfMessagesReceived     │ │
│ │                                                             │ │
│ │ Custom Metrics (Potential):                                 │ │
│ │ ├─ Order processing success rate                           │ │
│ │ ├─ Business rule violation counts                          │ │
│ │ └─ End-to-end processing latency                           │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 9. Security and IAM Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Model                              │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                   IAM Roles                                 │ │
│ │                                                             │ │
│ │ API Handler Role:                                           │ │
│ │ ├─ states:StartExecution (Step Functions)                   │ │
│ │ ├─ dynamodb:GetItem, PutItem, Query, Scan                   │ │
│ │ └─ logs:CreateLogGroup, CreateLogStream, PutLogEvents       │ │
│ │                                                             │ │
│ │ Validator Role:                                             │ │
│ │ └─ logs:* (Basic execution only)                            │ │
│ │                                                             │ │
│ │ Order Storage Role:                                         │ │
│ │ ├─ dynamodb:PutItem, GetItem, UpdateItem                    │ │
│ │ └─ logs:*                                                   │ │
│ │                                                             │ │
│ │ Fulfillment Role:                                           │ │
│ │ ├─ dynamodb:PutItem, GetItem, UpdateItem                    │ │
│ │ ├─ sqs:ReceiveMessage, DeleteMessage, GetQueueAttributes   │ │
│ │ └─ logs:*                                                   │ │
│ │                                                             │ │
│ │ DLQ Handler Role:                                           │ │
│ │ ├─ dynamodb:PutItem                                         │ │
│ │ ├─ sqs:ReceiveMessage, DeleteMessage, GetQueueAttributes   │ │
│ │ └─ logs:*                                                   │ │
│ │                                                             │ │
│ │ Step Functions Role:                                        │ │
│ │ ├─ lambda:InvokeFunction (All order processing Lambdas)     │ │
│ │ ├─ sqs:SendMessage                                          │ │
│ │ └─ logs:* (Execution logging)                               │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                 Data Encryption                             │ │
│ │                                                             │ │
│ │ At Rest:                                                    │ │
│ │ ├─ DynamoDB: AWS managed encryption                         │ │
│ │ ├─ S3: AES-256 server-side encryption                       │ │
│ │ └─ SQS: AWS managed encryption                              │ │
│ │                                                             │ │
│ │ In Transit:                                                 │ │
│ │ ├─ HTTPS for all API calls                                  │ │
│ │ ├─ TLS for AWS service communication                        │ │
│ │ └─ VPC endpoints (potential enhancement)                    │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 10. Deployment and Infrastructure

```
┌─────────────────────────────────────────────────────────────────┐
│                 Infrastructure Layout                          │
│                                                                 │
│ AWS Account Structure:                                          │
│ ├─ Region: us-east-1                                            │
│ ├─ Environments: dev, staging, prod                             │ │
│ └─ Resource Naming: {project}-{env}-{resource}                  │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                  Global Resources                           │ │
│ │                                                             │ │
│ │ S3 Buckets:                                                 │ │
│ │ ├─ dofs-cicd-artifacts (Pipeline artifacts)                │ │
│ │ ├─ dofs-global-terraform-state-{random} (State storage)    │ │
│ │ └─ dofs-{env}-lambda-deployments (Lambda packages)         │ │
│ │                                                             │ │
│ │ DynamoDB Tables:                                            │ │
│ │ └─ dofs-global-terraform-locks (State locking)             │ │
│ │                                                             │ │
│ │ CodePipeline:                                               │ │
│ │ ├─ dofs-nonprod-pipeline (dev → staging)                   │ │
│ │ └─ dofs-prod-pipeline (main → prod with approval)          │ │
│ │                                                             │ │
│ │ CodeBuild Projects:                                         │ │
│ │ ├─ dofs-nonprod-dev                                         │ │
│ │ ├─ dofs-nonprod-staging                                     │ │
│ │ └─ dofs-prod                                                │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │              Per-Environment Resources                      │ │
│ │                                                             │ │
│ │ API Gateway:                                                │ │
│ │ └─ dofs-{env}-api                                           │ │
│ │                                                             │ │
│ │ Lambda Functions:                                           │ │
│ │ ├─ dofs-{env}-api-handler                                   │ │
│ │ ├─ dofs-{env}-validator                                     │ │
│ │ ├─ dofs-{env}-order-storage                                 │ │
│ │ ├─ dofs-{env}-fulfill-order                                 │ │
│ │ └─ dofs-{env}-dlq-handler                                   │ │
│ │                                                             │ │
│ │ Step Functions:                                             │ │
│ │ └─ dofs-{env}-order-processing                              │ │
│ │                                                             │ │
│ │ DynamoDB Tables:                                            │ │
│ │ ├─ dofs-{env}-orders                                        │ │
│ │ └─ dofs-{env}-failed-orders                                 │ │
│ │                                                             │ │
│ │ SQS Queues:                                                 │ │
│ │ ├─ dofs-{env}-order-queue                                   │ │
│ │ └─ dofs-{env}-order-dlq                                     │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Whiteboard Summary

### Quick Reference for Whiteboard Sessions:

**Core Flow**: 
```
Client → API GW → Lambda → Step Functions → [Validate → Store → Queue] → Fulfill → DB
```

**Key Numbers**:
- 5 Lambda Functions
- 2 DynamoDB Tables  
- 2 SQS Queues
- 1 Step Function (6 states)
- 13+ AWS Services Total

**Error Paths**:
- Validation → ValidationFailed
- Storage → StorageFailed  
- Queue → QueueFailed
- Fulfillment → DLQ → Failed Orders Table

**Success Rate**: 70% by design (configurable)

This architecture map provides everything needed for whiteboard discussions, system design sessions, and technical documentation. Each section can be drawn independently or combined for different levels of detail.