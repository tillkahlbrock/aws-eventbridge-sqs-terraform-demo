variable "region" {
  description = "AWS region of the demo. All accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "platform_profile" {
  description = "AWS profile with administrative access to the platform account."
  type        = string
  default     = null
}

variable "receiver_profile" {
  description = "AWS profile with administrative access to the receiver workload account."
  type        = string
  default     = null
}

variable "github_repository" {
  description = "Repository that may assume the pipeline role, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "The github_repository must have the form owner/name."
  }
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set this to false when the platform account already has one."
  type        = bool
  default     = true
}

variable "state_bucket_name" {
  description = "S3 bucket for the Terraform state. It must match the backend block of every stack."
  type        = string
  default     = "async-demo-terraform-state"
}

variable "pipeline_role_name" {
  description = "Name of the role that GitHub Actions assumes."
  type        = string
  default     = "github-actions-eventing-repo"
}

variable "platform_deploy_role_name" {
  description = "Name of the deploy role in the platform account."
  type        = string
  default     = "terraform-platform-deploy"
}

variable "receiver_deploy_role_name" {
  description = "Name of the deploy role in the receiver workload account."
  type        = string
  default     = "terraform-fulfillment-service-deploy"
}
