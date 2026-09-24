provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        ManagedBy = "Terraform"
        Project   = var.project_name
        Purpose   = "RemoteStateBackend"
      },
      var.tags
    )
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  repo_full  = "${var.github_owner}/${var.github_repo}"
}
