# DOFS Terraform Infrastructure

This directory contains the infrastructure as code for the Distributed Order Fulfillment System (DOFS).

## Architecture

### Directory Structure
```
terraform/
├── environments/
│   ├── global/              # Shared infrastructure (S3 backend, DynamoDB tables)
│   └── multi-env/          # Application stack for any environment
│       ├── dev.tfvars      # Development configuration
│       ├── staging.tfvars  # Staging configuration (create as needed)
│       └── prod.tfvars     # Production configuration (create as needed)
├── modules/                # Reusable Terraform modules
├── cicd/                  # CI/CD pipeline configuration
└── workspace-setup.sh    # Workspace management script
```

### Environment Strategy
- **Global Environment**: Shared resources (S3 backend, DynamoDB tables)
- **Multi-Environment**: Application resources deployed to different workspaces
- **Terraform Workspaces**: Provide state isolation between environments
- **tfvars Files**: Environment-specific configuration values

## Deployment Process

### 1. Deploy Global Infrastructure (One-time)
```bash
./workspace-setup.sh global
cd environments/global
terraform plan
terraform apply
```

### 2. Configure Backend for Multi-Environment
After global deployment, update the backend configuration in `environments/multi-env/backend.tf` with the actual S3 bucket name.

### 3. Deploy Application Environment
```bash
./workspace-setup.sh dev
cd environments/multi-env
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### 4. Add Additional Environments
```bash
# Create staging.tfvars or prod.tfvars
./workspace-setup.sh staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

## Workspace Management

### List Workspaces
```bash
cd environments/multi-env
terraform workspace list
```

### Switch Workspaces
```bash
terraform workspace select dev
terraform workspace select staging
```

### Show Current Workspace
```bash
terraform workspace show
```

## Environment Configuration

Each environment is configured via its respective `.tfvars` file:

- `dev.tfvars`: Development environment settings
- `staging.tfvars`: Staging environment settings
- `prod.tfvars`: Production environment settings

## Resource Naming Convention

Resources follow the pattern: `{project_name}-{environment}-{resource_type}`

Examples:
- `dofs-dev-api-gateway`
- `dofs-staging-order-queue`
- `dofs-global-terraform-state-abc12345`