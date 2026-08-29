variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "deploy_role_arn" {
  description = "Role in the sender workload account that the pipeline assumes to apply this stack."
  type        = string
}

variable "platform_read_role_arn" {
  description = "Read-only role in the platform account. The stack uses it to resolve the shared event bus."
  type        = string
}

variable "event_bus_name" {
  description = "Name of the shared event bus. The name is the contract with the Platform Team."
  type        = string
  default     = "async-demo"
}
