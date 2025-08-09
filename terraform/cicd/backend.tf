terraform {
  backend "s3" {
    bucket         = "dofs-global-terraform-state-5ju06wiy"
    key            = "cicd/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dofs-global-terraform-locks"
    encrypt        = true
  }
}


