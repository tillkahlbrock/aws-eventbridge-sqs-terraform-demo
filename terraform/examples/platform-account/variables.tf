variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile of the platform account. Leave it null to authenticate through environment variables."
  type        = string
  default     = null
}

variable "event_bus_name" {
  description = "Name of the shared event bus."
  type        = string
  default     = "async-demo"
}

variable "sender_account_id" {
  description = "AWS account ID of the sender workload account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.sender_account_id))
    error_message = "The sender_account_id must be exactly 12 digits."
  }
}
