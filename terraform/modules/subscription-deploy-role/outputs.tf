output "role_arn" {
  description = "ARN of the role that the pipeline assumes to apply consumer stacks in the platform account."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the role in the platform account."
  value       = aws_iam_role.this.name
}
