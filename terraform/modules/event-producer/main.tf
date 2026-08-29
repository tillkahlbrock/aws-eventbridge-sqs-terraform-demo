# Sender Product Team resources. They are deployed into the sender workload account.
# This module creates no event bus. It only grants permission to publish to the shared bus.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  tags = merge({
    ManagedBy   = "Terraform"
    Environment = "demo"
    Component   = "producer"
  }, var.tags)

  demo_role_name = coalesce(var.demo_role_name, "${var.policy_name}-role")

  trusted_principal_arns = length(var.demo_role_trusted_principal_arns) > 0 ? var.demo_role_trusted_principal_arns : [
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
}

resource "aws_iam_policy" "put_events" {
  name        = var.policy_name
  description = "Allows events:PutEvents on the shared platform event bus only."
  tags        = local.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutEventsOnSharedPlatformBus"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = var.event_bus_arn
      }
    ]
  })
}

resource "aws_iam_role" "demo" {
  count = var.create_demo_role ? 1 : 0

  name = local.demo_role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTrustedPrincipalsToAssumeDemoRole"
        Effect = "Allow"
        Principal = {
          AWS = local.trusted_principal_arns
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "demo" {
  count = var.create_demo_role ? 1 : 0

  role       = aws_iam_role.demo[0].name
  policy_arn = aws_iam_policy.put_events.arn
}
