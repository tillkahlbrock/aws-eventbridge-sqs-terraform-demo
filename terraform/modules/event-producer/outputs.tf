output "iam_policy_arn" {
  description = "ARN of the IAM policy that allows events:PutEvents on the shared event bus. Attach it to the runtime role of the service."
  value       = aws_iam_policy.put_events.arn
}
