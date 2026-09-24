resource "aws_s3_bucket" "workload" {
  bucket = "${var.project_name}-${var.environment}-workload-${var.bucket_suffix}"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-workload"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_s3_bucket_versioning" "workload" {
  bucket = aws_s3_bucket.workload.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "workload" {
  bucket = aws_s3_bucket.workload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "workload" {
  bucket = aws_s3_bucket.workload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ssm_parameter" "config" {
  name = "/${var.project_name}/${var.environment}/config"
  type = "String"
  value = jsonencode({
    environment = var.environment
    bucket      = aws_s3_bucket.workload.id
    region      = data.aws_region.current.name
    deployed_at = timestamp()
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-config"
      Environment = var.environment
    },
    var.tags
  )
}

data "aws_region" "current" {}
