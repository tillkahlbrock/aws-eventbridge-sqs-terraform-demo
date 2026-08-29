variable "event_bus_name" {
  description = "Name of the shared event bus. The deployer role can manage rules on this bus only."
  type        = string
}

variable "event_bus_arn" {
  description = "ARN of the shared event bus."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z0-9-]+:events:[a-z0-9-]+:[0-9]{12}:event-bus/.+$", var.event_bus_arn))
    error_message = "The event_bus_arn must be an EventBridge event bus ARN."
  }
}

variable "trusted_principal_arns" {
  description = "Principals that can assume the deployer role. Supply the pipeline role of the central repository."
  type        = list(string)

  validation {
    condition     = length(var.trusted_principal_arns) > 0
    error_message = "At least one trusted principal is required. An unassumable role has no purpose."
  }
}

variable "role_name" {
  description = "Name of the deployer role in the platform account."
  type        = string
  default     = "event-subscription-deployer"
}

variable "permissions_boundary_name" {
  description = "Name of the permissions boundary policy. Consumer stacks look the policy up by this name."
  type        = string
  default     = "event-subscription-boundary"
}

variable "subscription_role_path" {
  description = "IAM path for the EventBridge execution roles that consumer stacks create. The deployer role cannot touch roles outside this path."
  type        = string
  default     = "/event-subscriptions/"

  validation {
    condition     = can(regex("^/.*/$", var.subscription_role_path))
    error_message = "The subscription_role_path must start and end with a slash."
  }
}

variable "tags" {
  description = "Additional tags to apply to taggable resources."
  type        = map(string)
  default     = {}
}
