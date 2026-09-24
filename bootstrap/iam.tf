# Plan role: read-only + state access, used for PR plan jobs
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
            "token.actions.githubusercontent.com:sub" = "repo:${local.repo_full}:*"
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
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Sid      = "StateBucketList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.terraform_state.arn
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

# Apply roles per environment: full access scoped to repo + environment/branch
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
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Scope to GitHub Environment for stage/prod, or main branch for dev
            "token.actions.githubusercontent.com:sub" = each.key == "dev" ? "repo:${local.repo_full}:ref:refs/heads/main" : "repo:${local.repo_full}:environment:${each.key}"
          }
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
        Sid    = "FullAccessForEnvironment"
        Effect = "Allow"
        Action = [
          "s3:*",
          "ssm:*",
          "iam:GetRole",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Sid      = "StateBucketList"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.terraform_state.arn
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
