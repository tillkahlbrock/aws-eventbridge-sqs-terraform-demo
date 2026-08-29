# Product Team B owns this stack. The Platform Team reviews and merges the change.
#
# A routine change to this stack edits the event pattern and nothing else.
# Keep the stack this small. It keeps review mechanical.

data "aws_cloudwatch_event_bus" "shared" {
  provider = aws.platform

  name = var.event_bus_name
}

data "aws_iam_policy" "subscription_boundary" {
  provider = aws.platform

  name = var.permissions_boundary_name
}

module "order_created_subscription" {
  source = "../../../modules/event-consumer"

  providers = {
    aws.platform = aws.platform
    aws.receiver = aws.receiver
  }

  event_bus_name    = data.aws_cloudwatch_event_bus.shared.name
  event_bus_arn     = data.aws_cloudwatch_event_bus.shared.arn
  subscription_name = "fulfillment-service-order-created"
  queue_name        = "fulfillment-service-order-created"
  dlq_name          = "fulfillment-service-order-created-dlq"

  execution_role_permissions_boundary_arn = data.aws_iam_policy.subscription_boundary.arn

  event_pattern = {
    source        = ["com.example.orders"]
    "detail-type" = ["OrderCreated"]
  }
}

output "queue_url" {
  description = "URL of the consumer queue. Use it to read test events manually."
  value       = module.order_created_subscription.queue_url
}

output "queue_arn" {
  description = "ARN of the consumer queue."
  value       = module.order_created_subscription.queue_arn
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue."
  value       = module.order_created_subscription.dlq_arn
}

output "event_rule_name" {
  description = "Name of the EventBridge rule in the platform account."
  value       = module.order_created_subscription.event_rule_name
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule in the platform account."
  value       = module.order_created_subscription.event_rule_arn
}

output "eventbridge_execution_role_arn" {
  description = "ARN of the platform-side EventBridge execution role."
  value       = module.order_created_subscription.eventbridge_execution_role_arn
}
