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

variable "github_subject_patterns" {
  description = "Subject claims that may assume the pipeline role. GitHub issues repo:<owner>@<owner-id>/<name>@<repo-id>:<ref> for this repository, not repo:<owner>/<name>:<ref>. Read the ids with: gh api repos/OWNER/NAME --jq '.owner.id, .id'"
  type        = list(string)

  validation {
    condition     = length(var.github_subject_patterns) > 0
    error_message = "At least one subject pattern is required."
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

variable "additional_trusted_principal_arns" {
  description = "Gives these principal temporary access to deploy. Just for demo purpose."
  type        = list(string)
  default     = []
}
