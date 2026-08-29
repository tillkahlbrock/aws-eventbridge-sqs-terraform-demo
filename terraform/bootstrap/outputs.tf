output "pipeline_role_arn" {
  description = "Set this as the PIPELINE_ROLE_ARN repository variable."
  value       = aws_iam_role.pipeline.arn
}

output "platform_deploy_role_arn" {
  description = "Set this as the PLATFORM_DEPLOY_ROLE_ARN repository variable."
  value       = aws_iam_role.platform_deploy.arn
}

output "receiver_deploy_role_arn" {
  description = "Set this as the FULFILLMENT_SERVICE_DEPLOY_ROLE_ARN repository variable."
  value       = aws_iam_role.receiver_deploy.arn
}

output "state_bucket_name" {
  description = "Bucket that the backend block of every stack must name."
  value       = aws_s3_bucket.state.id
}
