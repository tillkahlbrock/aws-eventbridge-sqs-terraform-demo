# Platform Team resource. It is deployed into the platform account.
#
# The pipeline holds credentials for all three accounts. This role limits what a
# consumer stack can do in the platform account.
#
# It does not defend against product teams. The Platform Team reviews and merges
# every change, so that would be circular. It defends against two things that
# review does not cover:
#
#   1. A consumer stack overwriting the event bus resource policy. That policy is
#      last-write-wins and lives in the platform stack state, so Terraform gives
#      no warning if another stack replaces it and locks out every producer.
#   2. A compromised pipeline. Review gates this repository. It does not gate the
#      actions, providers and Terraform binary that the runner executes.

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

  # Rule ARNs carry the bus name as the first path segment.
  bus_rule_arn_pattern = "arn:${local.partition}:events:${data.aws_region.current.region}:${local.account_id}:rule/${var.event_bus_name}/*"

  execution_role_arn_pattern = "arn:${local.partition}:iam::${local.account_id}:role/${var.execution_role_name_pattern}"
}

resource "aws_iam_role" "this" {
  name = var.role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPipelineToAssumeDeployRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_principal_arns
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "manage-subscriptions-on-shared-bus"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSharedEventBus"
        Effect   = "Allow"
        Action   = "events:DescribeEventBus"
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
        Sid    = "ManageExecutionRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:UpdateAssumeRolePolicy",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
        ]
        Resource = local.execution_role_arn_pattern
      },
      {
        # The rule target sets role_arn, so the stack must pass the role.
        Sid      = "PassExecutionRoleToEventBridgeOnly"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = local.execution_role_arn_pattern
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "events.amazonaws.com"
          }
        }
      },
      {
        # The event bus itself belongs to the platform stack. Its resource policy
        # is last-write-wins, so this deny is the control that matters most.
        Sid    = "DenyChangesToTheSharedBusItself"
        Effect = "Deny"
        Action = [
          "events:CreateEventBus",
          "events:DeleteEventBus",
          "events:UpdateEventBus",
          "events:PutPermission",
          "events:RemovePermission",
        ]
        Resource = "*"
      },
    ]
  })
}
