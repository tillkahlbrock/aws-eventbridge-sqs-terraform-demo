output "deployer_role_arn" {
  description = "ARN of the role that the pipeline assumes to apply consumer stacks in the platform account."
  value       = aws_iam_role.deployer.arn
}

output "permissions_boundary_arn" {
  description = "ARN of the permissions boundary that every EventBridge execution role must carry."
  value       = aws_iam_policy.boundary.arn
}

output "permissions_boundary_name" {
  description = "Name of the permissions boundary. Consumer stacks look the policy up by this name."
  value       = aws_iam_policy.boundary.name
}

output "subscription_role_path" {
  description = "IAM path under which consumer stacks must create their EventBridge execution role."
  value       = var.subscription_role_path
}
