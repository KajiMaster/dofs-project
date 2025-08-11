# ================================
# CI/CD PIPELINE INFRASTRUCTURE
# ================================

# Shared artifact bucket for both pipelines
resource "aws_s3_bucket" "cicd_artifacts" {
  bucket = "${var.project_name}-cicd-artifacts"
}

resource "aws_s3_bucket_versioning" "cicd_artifacts" {
  bucket = aws_s3_bucket.cicd_artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cicd_artifacts" {
  bucket = aws_s3_bucket.cicd_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# GitHub repository configuration  
variable "github_repo" {
  type        = string
  description = "GitHub repository in format: owner/repo"
}

variable "github_connection_arn" {
  type        = string
  default     = ""
  description = "AWS CodeStar Connection ARN for GitHub (leave empty to use GitHub v1 with token)"
}

variable "github_token" {
  type        = string
  default     = ""
  description = "GitHub personal access token (leave empty to use SSM parameter)"
  sensitive   = true
}

# Retrieve GitHub token from AWS Systems Manager Parameter Store (for legacy support)
data "aws_ssm_parameter" "github_token" {
  name            = "/github/personal-access-token"
  with_decryption = true
}

# CodeStar Connection for GitHub (recommended approach)
resource "aws_codestarconnections_connection" "github" {
  count         = var.github_connection_arn == "" ? 1 : 0
  name          = "${var.project_name}-github-connection"
  provider_type = "GitHub"
}

# ================================
# NON-PROD PIPELINE (DEV → STAGING)
# ================================

# CodeBuild role for non-prod pipeline
resource "aws_iam_role" "nonprod_codebuild_role" {
  name = "${var.project_name}-nonprod-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "nonprod_codebuild_policy" {
  name = "${var.project_name}-nonprod-codebuild-policy"
  role = aws_iam_role.nonprod_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream", 
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:*"
        ],
        Resource = [
          aws_s3_bucket.cicd_artifacts.arn,
          "${aws_s3_bucket.cicd_artifacts.arn}/*",
          "arn:aws:s3:::dofs-global-terraform-state-${random_string.suffix.result}",
          "arn:aws:s3:::dofs-global-terraform-state-${random_string.suffix.result}/*",
          "arn:aws:s3:::dofs-*-lambda-deployments",
          "arn:aws:s3:::dofs-*-lambda-deployments/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem", 
          "dynamodb:DeleteItem"
        ],
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/dofs-global-terraform-locks"
      },
      {
        Effect = "Allow",
        Action = [
          "codecommit:GitPull"
        ],
        Resource = "*"
      },
      # Broad permissions for Terraform to manage AWS resources in non-prod
      {
        Effect = "Allow",
        Action = [
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "sqs:*",
          "states:*",
          "iam:*",
          "logs:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# CodeBuild project for non-prod (DEV)
resource "aws_codebuild_project" "nonprod_dev" {
  name         = "${var.project_name}-nonprod-dev"
  service_role = aws_iam_role.nonprod_codebuild_role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }
  
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
    environment_variable {
      name  = "TF_WORKSPACE"
      value = "dev"
    }
    environment_variable {
      name  = "TF_VAR_FILE"
      value = "dev.tfvars"
    }
  }
  
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec-nonprod.yml"
  }
}

# CodeBuild project for non-prod (STAGING)
resource "aws_codebuild_project" "nonprod_staging" {
  name         = "${var.project_name}-nonprod-staging"
  service_role = aws_iam_role.nonprod_codebuild_role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }
  
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
    environment_variable {
      name  = "TF_WORKSPACE"
      value = "staging"
    }
    environment_variable {
      name  = "TF_VAR_FILE"
      value = "staging.tfvars"
    }
  }
  
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec-nonprod.yml"
  }
}

# CodePipeline role for non-prod
resource "aws_iam_role" "nonprod_codepipeline_role" {
  name = "${var.project_name}-nonprod-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "nonprod_codepipeline_policy" {
  name = "${var.project_name}-nonprod-codepipeline-policy"
  role = aws_iam_role.nonprod_codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          aws_s3_bucket.cicd_artifacts.arn,
          "${aws_s3_bucket.cicd_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = [
          aws_codebuild_project.nonprod_dev.arn,
          aws_codebuild_project.nonprod_staging.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = var.github_connection_arn != "" ? var.github_connection_arn : aws_codestarconnections_connection.github[0].arn
      }
    ]
  })
}

# Non-Prod Pipeline (DEV → STAGING)
resource "aws_codepipeline" "nonprod" {
  name          = "${var.project_name}-nonprod-pipeline"
  role_arn      = aws_iam_role.nonprod_codepipeline_role.arn
  pipeline_type = "V2"
  
  depends_on = [aws_codestarconnections_connection.github]

  artifact_store {
    location = aws_s3_bucket.cicd_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.github_connection_arn != "" ? var.github_connection_arn : aws_codestarconnections_connection.github[0].arn
        FullRepositoryId = var.github_repo
        BranchName       = "develop"
      }
    }
  }

  stage {
    name = "Deploy-Dev"
    action {
      name             = "Deploy-Dev"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["dev_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.nonprod_dev.name
      }
    }
  }

  stage {
    name = "Deploy-Staging"
    action {
      name             = "Deploy-Staging"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["staging_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.nonprod_staging.name
      }
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = ["develop"]
        }
      }
    }
  }
}

# ================================
# PROD PIPELINE (with manual approval)
# ================================

# CodeBuild role for prod pipeline
resource "aws_iam_role" "prod_codebuild_role" {
  name = "${var.project_name}-prod-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "prod_codebuild_policy" {
  name = "${var.project_name}-prod-codebuild-policy"
  role = aws_iam_role.prod_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          aws_s3_bucket.cicd_artifacts.arn,
          "${aws_s3_bucket.cicd_artifacts.arn}/*",
          "arn:aws:s3:::dofs-global-terraform-state-${random_string.suffix.result}",
          "arn:aws:s3:::dofs-global-terraform-state-${random_string.suffix.result}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/dofs-global-terraform-locks"
      },
      {
        Effect = "Allow",
        Action = [
          "codecommit:GitPull"
        ],
        Resource = "*"
      },
      # Same broad permissions for prod (could be more restrictive)
      {
        Effect = "Allow",
        Action = [
          "lambda:*",
          "apigateway:*", 
          "dynamodb:*",
          "sqs:*",
          "states:*",
          "iam:*",
          "logs:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# CodeBuild project for prod
resource "aws_codebuild_project" "prod" {
  name         = "${var.project_name}-prod"
  service_role = aws_iam_role.prod_codebuild_role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }
  
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "true"
    }
    environment_variable {
      name  = "TF_WORKSPACE"
      value = "prod"
    }
    environment_variable {
      name  = "TF_VAR_FILE"
      value = "prod.tfvars"
    }
  }
  
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec-prod.yml"
  }
}

# CodePipeline role for prod
resource "aws_iam_role" "prod_codepipeline_role" {
  name = "${var.project_name}-prod-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "prod_codepipeline_policy" {
  name = "${var.project_name}-prod-codepipeline-policy"
  role = aws_iam_role.prod_codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion", 
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          aws_s3_bucket.cicd_artifacts.arn,
          "${aws_s3_bucket.cicd_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = aws_codebuild_project.prod.arn
      },
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = var.github_connection_arn != "" ? var.github_connection_arn : aws_codestarconnections_connection.github[0].arn
      }
    ]
  })
}

# Prod Pipeline (with manual approval)
resource "aws_codepipeline" "prod" {
  name     = "${var.project_name}-prod-pipeline"
  role_arn = aws_iam_role.prod_codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.cicd_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.github_connection_arn != "" ? var.github_connection_arn : aws_codestarconnections_connection.github[0].arn
        FullRepositoryId = var.github_repo
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Manual-Approval"
    action {
      name     = "Manual-Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Please review and approve production deployment"
      }
    }
  }

  stage {
    name = "Deploy-Prod"
    action {
      name             = "Deploy-Prod"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["prod_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.prod.name
      }
    }
  }
}