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

variable "tags" {
  description = "Additional tags to apply to taggable resources."
  type        = map(string)
  default     = {}
}
