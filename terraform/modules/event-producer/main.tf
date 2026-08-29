# Sender Product Team resources. They are deployed into the sender workload account.
# This module creates no event bus. It only grants permission to publish to the shared bus.
#
# The module creates no identity. The product team attaches this policy to the
# runtime role of its own service.

locals {
  tags = merge({
    ManagedBy   = "Terraform"
    Environment = "demo"
    Component   = "producer"
  }, var.tags)
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
