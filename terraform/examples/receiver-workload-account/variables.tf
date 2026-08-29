variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "platform_aws_profile" {
  description = "AWS CLI profile of the platform account. Leave it null to authenticate through environment variables."
  type        = string
  default     = null
}

variable "receiver_aws_profile" {
  description = "AWS CLI profile of the receiver workload account. Leave it null to authenticate through environment variables."
  type        = string
  default     = null
}

variable "event_bus_name" {
  description = "Name of the shared event bus. Copy this value from the platform deployment output."
  type        = string
}

variable "event_bus_arn" {
  description = "ARN of the shared event bus. Copy this value from the platform deployment output."
  type        = string
}
