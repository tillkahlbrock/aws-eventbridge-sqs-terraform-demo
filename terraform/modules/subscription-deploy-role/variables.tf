variable "event_bus_name" {
  description = "Name of the shared event bus. The role can manage rules on this bus only."
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
  description = "Principals that can assume this role. Supply the pipeline role of the central repository."
  type        = list(string)

  validation {
    condition     = length(var.trusted_principal_arns) > 0
    error_message = "At least one trusted principal is required. An unassumable role has no purpose."
  }
}

variable "role_name" {
  description = "Name of the role in the platform account."
  type        = string
  default     = "event-subscription-deploy"
}

variable "execution_role_name_pattern" {
  description = "Name pattern of the EventBridge execution roles that consumer stacks create. The event-consumer module derives the name from the subscription name and this suffix."
  type        = string
  default     = "*-eventbridge-target"
}

variable "tags" {
  description = "Additional tags to apply to taggable resources."
  type        = map(string)
  default     = {}
}
