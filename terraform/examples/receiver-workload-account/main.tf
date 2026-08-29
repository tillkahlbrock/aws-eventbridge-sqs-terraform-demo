# Product Team B deploys this root last.
# The event pattern below is the subscription. It selects the demo order events.

module "order_events_consumer" {
  source = "../../modules/event-consumer"

  providers = {
    aws.platform = aws.platform
    aws.receiver = aws.receiver
  }

  event_bus_name    = var.event_bus_name
  event_bus_arn     = var.event_bus_arn
  subscription_name = "order-created-demo"
  queue_name        = "order-created-demo"
  dlq_name          = "order-created-demo-dlq"

  event_pattern = {
    source        = ["com.example.orders"]
    "detail-type" = ["OrderCreated"]
  }
}

output "queue_url" {
  description = "URL of the consumer queue. Use it to read test events manually."
  value       = module.order_events_consumer.queue_url
}

output "queue_arn" {
  description = "ARN of the consumer queue."
  value       = module.order_events_consumer.queue_arn
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue."
  value       = module.order_events_consumer.dlq_arn
}

output "event_rule_name" {
  description = "Name of the EventBridge rule in the platform account."
  value       = module.order_events_consumer.event_rule_name
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule in the platform account."
  value       = module.order_events_consumer.event_rule_arn
}

output "eventbridge_execution_role_arn" {
  description = "ARN of the platform-side EventBridge execution role."
  value       = module.order_events_consumer.eventbridge_execution_role_arn
}
