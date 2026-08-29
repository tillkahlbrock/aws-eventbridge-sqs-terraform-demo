# The Platform Team deploys this root first.
# Record both outputs and hand them to the product teams.

module "event_platform" {
  source = "../../modules/event-platform"

  name                         = var.event_bus_name
  allowed_producer_account_ids = [var.sender_account_id]
}

output "event_bus_name" {
  description = "Name of the shared event bus."
  value       = module.event_platform.event_bus_name
}

output "event_bus_arn" {
  description = "ARN of the shared event bus."
  value       = module.event_platform.event_bus_arn
}
