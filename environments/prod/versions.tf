terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend config is loaded from backend-dev.hcl
    # Run: terraform init -backend-config=backend-dev.hcl
  }
}
