# Product Team A owns this stack. The Platform Team reviews and merges the change.
#
# The bus ARN is resolved, not pasted. The bus name is the contract.
# The lookup fails clearly if the platform stack has not run yet.

data "aws_cloudwatch_event_bus" "shared" {
  provider = aws.platform

  name = var.event_bus_name
}

module "event_producer" {
  source = "../../../modules/event-producer"

  event_bus_arn = data.aws_cloudwatch_event_bus.shared.arn
  policy_name   = "order-service-put-events"

  # A real workload attaches the policy to its own runtime role.
  create_demo_role = true
}

output "iam_policy_arn" {
  description = "ARN of the policy that allows events:PutEvents on the shared event bus."
  value       = module.event_producer.iam_policy_arn
}

output "demo_role_arn" {
  description = "ARN of the optional demo role."
  value       = module.event_producer.demo_role_arn
}
