data "aws_cloudwatch_event_bus" "shared" {
  provider = aws.platform

  name = var.event_bus_name
}

module "event_producer" {
  source = "../../../modules/event-producer"

  event_bus_arn = data.aws_cloudwatch_event_bus.shared.arn
  policy_name   = "order-service-put-events"
}

output "iam_policy_arn" {
  description = "ARN of the policy that allows events:PutEvents on the shared event bus."
  value       = module.event_producer.iam_policy_arn
}
