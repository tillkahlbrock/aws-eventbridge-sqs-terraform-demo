# The Platform Team owns this stack. It runs first in the pipeline.
#
# The stack publishes two contracts that the product stacks look up by name:
#   - the shared event bus
#   - the permissions boundary for EventBridge execution roles

module "event_platform" {
  source = "../../modules/event-platform"

  name                         = var.event_bus_name
  allowed_producer_account_ids = var.producer_account_ids
}

# Limits what a consumer stack can do in the platform account.
module "subscription_deployer_role" {
  source = "../../modules/subscription-deployer-role"

  event_bus_name         = module.event_platform.event_bus_name
  event_bus_arn          = module.event_platform.event_bus_arn
  trusted_principal_arns = var.pipeline_role_arns
}

output "event_bus_name" {
  description = "Name of the shared event bus."
  value       = module.event_platform.event_bus_name
}

output "event_bus_arn" {
  description = "ARN of the shared event bus."
  value       = module.event_platform.event_bus_arn
}

output "subscription_deployer_role_arn" {
  description = "Role that the pipeline assumes to apply consumer stacks in the platform account."
  value       = module.subscription_deployer_role.deployer_role_arn
}

output "subscription_permissions_boundary_name" {
  description = "Name of the permissions boundary that consumer stacks look up."
  value       = module.subscription_deployer_role.permissions_boundary_name
}
