variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "deploy_role_arn" {
  description = "Role in the platform account that the pipeline assumes to apply this stack."
  type        = string
}

variable "event_bus_name" {
  description = "Name of the shared event bus. This name is the contract that the product stacks look up."
  type        = string
  default     = "async-demo"
}

variable "producer_account_ids" {
  description = "AWS account IDs of the workload accounts that may publish to the shared event bus."
  type        = set(string)

  validation {
    condition     = length(var.producer_account_ids) > 0
    error_message = "At least one producer account is required."
  }
}

variable "pipeline_role_arns" {
  description = "Pipeline roles that may assume the subscription deploy role in the platform account."
  type        = list(string)
}
