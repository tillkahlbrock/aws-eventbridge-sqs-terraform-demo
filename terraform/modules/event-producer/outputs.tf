output "iam_policy_arn" {
  description = "ARN of the IAM policy that allows events:PutEvents on the shared event bus."
  value       = aws_iam_policy.put_events.arn
}

output "demo_role_arn" {
  description = "ARN of the optional demo role. It is null when create_demo_role is false."
  value       = one(aws_iam_role.demo[*].arn)
}
