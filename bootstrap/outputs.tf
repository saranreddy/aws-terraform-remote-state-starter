output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_lock.id
}

output "lock_table_arn" {
  description = "DynamoDB table ARN for state locking"
  value       = aws_dynamodb_table.terraform_lock.arn
}

output "github_plan_role_arn" {
  description = "IAM role ARN for GitHub Actions plan jobs"
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arns" {
  description = "IAM role ARNs for GitHub Actions apply jobs per environment"
  value = {
    for env, role in aws_iam_role.github_apply : env => role.arn
  }
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "backend_config" {
  description = "Backend configuration for environments (copy to backend.hcl files)"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_lock.id
  }
}
