# Platform Team resources. They are deployed into the platform account.
# The shared event bus is the only event bus in the demo.

data "aws_partition" "current" {}

locals {
  tags = merge({
    ManagedBy   = "Terraform"
    Environment = "demo"
    Component   = "platform"
  }, var.tags)

  producer_principals = [
    for account_id in var.allowed_producer_account_ids :
    "arn:${data.aws_partition.current.partition}:iam::${account_id}:root"
  ]
}

resource "aws_cloudwatch_event_bus" "this" {
  name = var.name
  tags = local.tags
}

# The resource policy authorizes the sender workload accounts.
# The sender identity also needs its own identity policy. See the event-producer module.
resource "aws_cloudwatch_event_bus_policy" "this" {
  count = length(var.allowed_producer_account_ids) > 0 ? 1 : 0

  event_bus_name = aws_cloudwatch_event_bus.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowConfiguredWorkloadAccountsToPutEvents"
        Effect = "Allow"
        Principal = {
          AWS = local.producer_principals
        }
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.this.arn
      }
    ]
  })
}
