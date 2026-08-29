variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "deploy_role_arn" {
  description = "Role in the receiver workload account that the pipeline assumes to apply this stack."
  type        = string
}

variable "subscription_deploy_role_arn" {
  description = "Scoped role in the platform account. The platform stack creates it."
  type        = string
}

variable "event_bus_name" {
  description = "Name of the shared event bus. The name is the contract with the Platform Team."
  type        = string
  default     = "async-demo"
}
