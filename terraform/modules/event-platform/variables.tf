variable "name" {
  description = "Name of the shared custom EventBridge event bus."
  type        = string
  default     = "async-demo"
}

variable "allowed_producer_account_ids" {
  description = "AWS account IDs of the workload accounts that can call events:PutEvents on the shared event bus. An empty set creates no resource policy."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.allowed_producer_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "Each producer account ID must be exactly 12 digits."
  }
}

variable "tags" {
  description = "Additional tags to apply to taggable resources."
  type        = map(string)
  default     = {}
}
