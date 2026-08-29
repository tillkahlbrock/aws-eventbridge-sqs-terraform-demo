variable "event_bus_arn" {
  description = "ARN of the shared event bus in the platform account. Copy this value from the platform deployment output."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z0-9-]+:events:[a-z0-9-]+:[0-9]{12}:event-bus/.+$", var.event_bus_arn))
    error_message = "The event_bus_arn must be an EventBridge event bus ARN, for example arn:aws:events:eu-central-1:111122223333:event-bus/async-demo."
  }
}

variable "policy_name" {
  description = "Name of the IAM policy that grants events:PutEvents on the shared event bus."
  type        = string
  default     = "async-demo-put-events"
}

variable "create_demo_role" {
  description = "Create an assumable demo role and attach the policy to it. Set this to false to attach the policy to an existing runtime role instead."
  type        = bool
  default     = true
}

variable "demo_role_name" {
  description = "Name of the optional demo role. Defaults to the policy name with a -role suffix."
  type        = string
  default     = null
}

variable "demo_role_trusted_principal_arns" {
  description = "Principals that can assume the demo role. Defaults to the root of the account that deploys this module."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to taggable resources."
  type        = map(string)
  default     = {}
}
