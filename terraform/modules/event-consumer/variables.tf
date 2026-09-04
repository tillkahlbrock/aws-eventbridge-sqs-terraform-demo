variable "event_bus_name" {
  description = "Name of the shared event bus in the platform account."
  type        = string
}

variable "event_bus_arn" {
  description = "ARN of the shared event bus in the platform account."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z0-9-]+:events:[a-z0-9-]+:[0-9]{12}:event-bus/.+$", var.event_bus_arn))
    error_message = "The event_bus_arn must be an EventBridge event bus ARN, for example arn:aws:events:eu-central-1:111122223333:event-bus/async-demo."
  }
}

variable "subscription_name" {
  description = "Stable name of the EventBridge rule that defines this subscription."
  type        = string
}

variable "event_pattern" {
  description = "EventBridge event pattern that selects the subscribed events. Supply a Terraform object or a JSON string."
  type        = any

  validation {
    condition     = can(jsondecode(var.event_pattern)) || can(keys(var.event_pattern))
    error_message = "The event_pattern must be a Terraform object or map, or a JSON string."
  }
}

variable "queue_name" {
  description = "Name of the SQS queue in the consumer's workload account."
  type        = string
}

variable "dlq_name" {
  description = "Name of the dead-letter queue in the consumer's workload account."
  type        = string
}

variable "max_receive_count" {
  description = "Number of receives after which a message moves to the dead-letter queue."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "The max_receive_count must be between 1 and 1000."
  }
}

variable "message_retention_seconds" {
  description = "Retention time of messages in the consumer queue. The demo default is four days."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Retention time of messages in the dead-letter queue. The demo default is 14 days."
  type        = number
  default     = 1209600
}

variable "target_dlq_name" {
  description = "Name of the rule's dead-letter queue in the platform account. Defaults to the subscription name with a -target-dlq suffix."
  type        = string
  default     = null
}

variable "target_dlq_message_retention_seconds" {
  description = "Retention time of messages in the rule's dead-letter queue. The demo default is 14 days."
  type        = number
  default     = 1209600
}

variable "eventbridge_execution_role_name" {
  description = "Name of the platform-side EventBridge execution role. Defaults to the subscription name with an -eventbridge-target suffix."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to taggable resources."
  type        = map(string)
  default     = {}
}
