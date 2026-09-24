# Plan role: read-only + state read + locking, used for PR plan jobs
resource "aws_iam_role" "github_plan" {
  name = "${var.project_name}-github-plan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow pull_request events and main branch (for plan on push)
            "token.actions.githubusercontent.com:sub" = [
              "repo:${local.repo_full}:pull_request",
              "repo:${local.repo_full}:ref:refs/heads/main"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_plan" {
  name = "plan-permissions"
  role = aws_iam_role.github_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WorkloadReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*-workload-*",
          "arn:aws:ssm:*:${local.account_id}:parameter/${var.project_name}/*"
        ]
      },
      {
        Sid    = "StateReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Sid    = "StateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
      }
    ]
  })
}

# Apply roles per environment: scoped access to environment resources only
resource "aws_iam_role" "github_apply" {
  for_each = toset(var.environments)
  name     = "${var.project_name}-github-apply-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = merge(
            {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            },
            each.key == "dev" ? {
              "token.actions.githubusercontent.com:sub" = "repo:${local.repo_full}:ref:refs/heads/main"
              } : {
              "token.actions.githubusercontent.com:sub" = "repo:${local.repo_full}:environment:${each.key}"
            }
          )
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_apply" {
  for_each = toset(var.environments)
  name     = "apply-permissions"
  role     = aws_iam_role.github_apply[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3WorkloadBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${each.key}-workload-*"
      },
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "ssm:ListTagsForResource"
        ]
        Resource = "arn:aws:ssm:*:${local.account_id}:parameter/${var.project_name}/${each.key}/*"
      },
      {
        Sid    = "StateReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/${each.key}/*"
      },
      {
        Sid      = "StateBucketList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.terraform_state.arn
        Condition = {
          StringLike = {
            "s3:prefix" = [each.key, "${each.key}/*"]
          }
        }
      },
      {
        Sid    = "StateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
        Condition = {
          StringLike = {
            "dynamodb:LeadingKeys" = ["${aws_s3_bucket.terraform_state.id}/${each.key}/*"]
          }
        }
      },
      {
        Sid    = "DenyStateBucketChanges"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutLifecycleConfiguration"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Sid    = "DenyLockTableChanges"
        Effect = "Deny"
        Action = [
          "dynamodb:DeleteTable",
          "dynamodb:UpdateTable"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
      },
      {
        Sid    = "DenyOtherEnvironmentState"
        Effect = "Deny"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          for env in var.environments : "${aws_s3_bucket.terraform_state.arn}/${env}/*"
          if env != each.key
        ]
      }
    ]
  })
}
