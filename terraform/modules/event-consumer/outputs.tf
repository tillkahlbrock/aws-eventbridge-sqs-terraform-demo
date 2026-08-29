output "queue_url" {
  description = "URL of the consumer queue in the receiver workload account."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN of the consumer queue in the receiver workload account."
  value       = aws_sqs_queue.this.arn
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue in the receiver workload account."
  value       = aws_sqs_queue.dlq.arn
}

output "event_rule_arn" {
  description = "ARN of the EventBridge rule in the platform account."
  value       = aws_cloudwatch_event_rule.this.arn
}

output "event_rule_name" {
  description = "Name of the EventBridge rule in the platform account."
  value       = aws_cloudwatch_event_rule.this.name
}

output "eventbridge_execution_role_arn" {
  description = "ARN of the platform-side role that EventBridge assumes to deliver events to the consumer queue."
  value       = aws_iam_role.eventbridge_target.arn
}
