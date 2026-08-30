variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "deploy_role_arn" {
  description = "Role in the fulfillment-service account that the pipeline assumes to apply this stack."
  type        = string
}

variable "platform_deploy_role_arn" {
  description = "Administrative role in the platform account that the pipeline assumes to create the EventBridge rule and its execution role."
  type        = string
}

variable "event_bus_name" {
  description = "Name of the shared event bus. The name is the contract with the Platform Team."
  type        = string
  default     = "async-demo"
}
