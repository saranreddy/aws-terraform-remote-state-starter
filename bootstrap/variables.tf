variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming (e.g., my-project)"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username (e.g., myorg)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g., my-repo)"
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state (must be globally unique)"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-state-lock"
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent S3 object versions are permanently deleted"
  type        = number
  default     = 90
}

variable "create_oidc_provider" {
  description = "Whether to create GitHub OIDC provider (set false if one already exists in your account)"
  type        = bool
  default     = true
}

variable "environments" {
  description = "List of environments (dev, stage, prod) for IAM role creation"
  type        = list(string)
  default     = ["dev", "stage", "prod"]
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
