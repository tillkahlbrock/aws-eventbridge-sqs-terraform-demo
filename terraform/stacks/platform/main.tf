module "event_platform" {
  source = "../../modules/event-platform"

  name                         = var.event_bus_name
  allowed_producer_account_ids = var.producer_account_ids
}

# Limits what a consumer stack can do in the platform account.
module "subscription_deploy_role" {
  source = "../../modules/subscription-deploy-role"

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

output "subscription_deploy_role_arn" {
  description = "Role that the pipeline assumes to apply consumer stacks in the platform account."
  value       = module.subscription_deploy_role.role_arn
}
