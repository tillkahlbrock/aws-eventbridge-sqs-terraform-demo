variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "platform_profile" {
  description = "AWS profile for the platform account. Leave it null to use the ambient credentials."
  type        = string
  default     = null
}

variable "receiver_profile" {
  description = "AWS profile for the receiver workload account. Leave it null to use the ambient credentials."
  type        = string
  default     = null
}

variable "event_bus_name" {
  description = "Name of the shared event bus. The name is the contract with the Platform Team."
  type        = string
  default     = "async-demo"
}
