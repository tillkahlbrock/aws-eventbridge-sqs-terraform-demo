
# Creates: Bus + sender policy
module "event_platform" {
  source = "../../modules/event-platform"

  name                         = var.event_bus_name
  allowed_producer_account_ids = var.producer_account_ids
}

output "event_bus_name" {
  description = "Name of the shared event bus."
  value       = module.event_platform.event_bus_name
}

output "event_bus_arn" {
  description = "ARN of the shared event bus."
  value       = module.event_platform.event_bus_arn
}
