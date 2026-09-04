data "aws_cloudwatch_event_bus" "shared" {
  provider = aws.platform

  name = var.event_bus_name
}

module "order_created_subscription" {
  source = "../../../modules/event-consumer"

  providers = {
    aws.platform = aws.platform
    aws.consumer = aws.fulfillment
  }

  event_bus_name    = data.aws_cloudwatch_event_bus.shared.name
  event_bus_arn     = data.aws_cloudwatch_event_bus.shared.arn
  subscription_name = "fulfillment-service-order-created"
  queue_name        = "fulfillment-service-order-created"
  dlq_name          = "fulfillment-service-order-created-dlq"

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

output "target_dlq_arn" {
  description = "ARN of the rule's dead-letter queue in the platform account."
  value       = module.order_created_subscription.target_dlq_arn
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
