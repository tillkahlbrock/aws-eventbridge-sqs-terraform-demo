# Platform Team resource. It is deployed into the platform account.
#
# In the central repository model, one pipeline applies every stack. The pipeline
# therefore holds credentials for the platform account. This role limits what a
# consumer stack can do there, so that a product team pull request cannot change
# the shared event bus or create unrelated IAM roles.
#
# The role is the deploy-time counterpart to the runtime permission model.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  tags = merge({
    ManagedBy   = "Terraform"
    Environment = "demo"
    Component   = "platform"
  }, var.tags)

  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id

  # Rules on the shared bus. Rule ARNs carry the bus name as the first path segment.
  bus_rule_arn_pattern = "arn:${local.partition}:events:${data.aws_region.current.region}:${local.account_id}:rule/${var.event_bus_name}/*"

  # EventBridge execution roles that consumer stacks create.
  subscription_role_arn_pattern = "arn:${local.partition}:iam::${local.account_id}:role${var.subscription_role_path}*"
}

# The boundary caps what a created execution role can ever do, whatever policy
# the consumer stack attaches to it.
resource "aws_iam_policy" "boundary" {
  name        = var.permissions_boundary_name
  description = "Permissions boundary for EventBridge execution roles created by consumer stacks."
  tags        = local.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DeliverToQueuesOnly"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "deployer" {
  name = var.role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPipelineToAssumeDeployerRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_principal_arns
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "deployer" {
  name = "manage-subscriptions-on-shared-bus"
  role = aws_iam_role.deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSharedEventBus"
        Effect = "Allow"
        Action = [
          "events:DescribeEventBus",
          "events:ListRules",
        ]
        Resource = var.event_bus_arn
      },
      {
        Sid    = "ManageRulesOnSharedBusOnly"
        Effect = "Allow"
        Action = [
          "events:DescribeRule",
          "events:PutRule",
          "events:DeleteRule",
          "events:EnableRule",
          "events:DisableRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:ListTargetsByRule",
          "events:ListTagsForResource",
          "events:TagResource",
          "events:UntagResource",
        ]
        Resource = local.bus_rule_arn_pattern
      },
      {
        # Creating or changing an execution role requires the boundary.
        Sid    = "CreateExecutionRolesWithBoundaryOnly"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:AttachRolePolicy",
        ]
        Resource = local.subscription_role_arn_pattern
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = aws_iam_policy.boundary.arn
          }
        }
      },
      {
        Sid    = "ManageExecutionRolesUnderSubscriptionPath"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListRoleTags",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
        ]
        Resource = local.subscription_role_arn_pattern
      },
      {
        # The rule target sets role_arn, so the deployer must pass the role.
        Sid      = "PassExecutionRoleToEventBridgeOnly"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = local.subscription_role_arn_pattern
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "events.amazonaws.com"
          }
        }
      },
      {
        # Without this deny, a consumer stack could drop its own boundary.
        Sid    = "DenyBoundaryRemoval"
        Effect = "Deny"
        Action = [
          "iam:DeleteRolePermissionsBoundary",
          "iam:PutRolePermissionsBoundary",
        ]
        Resource = "*"
      },
    ]
  })
}
