# Run once, by hand, with administrative credentials for both accounts.
# This root keeps local state: it creates the bucket that the other stacks use.
# In production a provisioning mechanism would roll these roles out.

data "aws_caller_identity" "platform" {
  provider = aws.platform
}

data "aws_caller_identity" "receiver" {
  provider = aws.receiver
}

data "aws_partition" "current" {
  provider = aws.platform
}

locals {
  tags = {
    ManagedBy   = "Terraform"
    Environment = "demo"
    Component   = "bootstrap"
  }

  partition = data.aws_partition.current.partition

  # Built from names, not from the resources, so the trust and the grant do not
  # form a dependency cycle.
  platform_deploy_role_arn = "arn:${local.partition}:iam::${data.aws_caller_identity.platform.account_id}:role/${var.platform_deploy_role_name}"
  receiver_deploy_role_arn = "arn:${local.partition}:iam::${data.aws_caller_identity.receiver.account_id}:role/${var.receiver_deploy_role_name}"

  administrator_access_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# --------------------------------------------------------------------------
# Terraform state, platform account
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  provider = aws.platform

  bucket = var.state_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "state" {
  provider = aws.platform

  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  provider = aws.platform

  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  provider = aws.platform

  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------------------------
# Pipeline identity, platform account
# --------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count    = var.create_github_oidc_provider ? 1 : 0
  provider = aws.platform

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count    = var.create_github_oidc_provider ? 0 : 1
  provider = aws.platform

  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "pipeline" {
  provider = aws.platform

  name = var.pipeline_role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGitHubActionsFromThisRepository"
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })
}

# The pipeline itself only assumes the deploy roles and reads and writes state.
resource "aws_iam_role_policy" "pipeline" {
  provider = aws.platform

  name = "assume-deploy-roles-and-use-state"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeDeployRoles"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          local.platform_deploy_role_arn,
          local.receiver_deploy_role_arn,
        ]
      },
      {
        # The S3 backend uses the ambient credentials, not the assumed role.
        Sid      = "ListStateBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid    = "ReadWriteState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${aws_s3_bucket.state.arn}/*"
      },
    ]
  })
}

# --------------------------------------------------------------------------
# Deploy roles
# --------------------------------------------------------------------------

resource "aws_iam_role" "platform_deploy" {
  provider = aws.platform

  name = var.platform_deploy_role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPipelineRoleToDeploy"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.pipeline.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "platform_deploy" {
  provider = aws.platform

  role       = aws_iam_role.platform_deploy.name
  policy_arn = local.administrator_access_arn
}

resource "aws_iam_role" "receiver_deploy" {
  provider = aws.receiver

  name = var.receiver_deploy_role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPipelineRoleToDeploy"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.pipeline.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "receiver_deploy" {
  provider = aws.receiver

  role       = aws_iam_role.receiver_deploy.name
  policy_arn = local.administrator_access_arn
}
