output "bucket_name" {
  description = "Name of the workload S3 bucket"
  value       = aws_s3_bucket.workload.id
}

output "bucket_arn" {
  description = "ARN of the workload S3 bucket"
  value       = aws_s3_bucket.workload.arn
}

output "ssm_parameter_name" {
  description = "Name of the SSM parameter"
  value       = aws_ssm_parameter.config.name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter"
  value       = aws_ssm_parameter.config.arn
}
