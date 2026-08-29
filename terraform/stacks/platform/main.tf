
# Creates: Bus + sender policy
module "event_platform" {
  source = "../../modules/event-platform"

  name                         = var.event_bus_name
  allowed_producer_account_ids = toset([for producer in local.producers : producer.account_id])
}

output "event_bus_name" {
  description = "Name of the shared event bus."
  value       = module.event_platform.event_bus_name
}

output "event_bus_arn" {
  description = "ARN of the shared event bus."
  value       = module.event_platform.event_bus_arn
}
