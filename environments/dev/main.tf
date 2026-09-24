provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        ManagedBy   = "Terraform"
        Project     = var.project_name
        Environment = var.environment
      },
      var.tags
    )
  }
}

module "workload" {
  source = "../../modules/simple-workload"

  environment   = var.environment
  project_name  = var.project_name
  bucket_suffix = var.bucket_suffix
  tags          = var.tags
}
