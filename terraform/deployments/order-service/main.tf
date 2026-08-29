# Product Team A deploys this root after shared-infra exists.
# The shared event bus ARN is passed as a variable. There is no remote-state reference.

module "event_producer" {
  source = "../../modules/event-producer"

  event_bus_arn    = var.event_bus_arn
  policy_name      = var.policy_name
  create_demo_role = var.create_demo_role
}

output "iam_policy_arn" {
  description = "ARN of the policy that allows events:PutEvents on the shared event bus."
  value       = module.event_producer.iam_policy_arn
}

output "demo_role_arn" {
  description = "ARN of the optional demo role."
  value       = module.event_producer.demo_role_arn
}
