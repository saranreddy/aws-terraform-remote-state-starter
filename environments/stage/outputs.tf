output "bucket_name" {
  description = "Name of the workload S3 bucket"
  value       = module.workload.bucket_name
}

output "bucket_arn" {
  description = "ARN of the workload S3 bucket"
  value       = module.workload.bucket_arn
}

output "ssm_parameter_name" {
  description = "Name of the SSM parameter"
  value       = module.workload.ssm_parameter_name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter"
  value       = module.workload.ssm_parameter_arn
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
