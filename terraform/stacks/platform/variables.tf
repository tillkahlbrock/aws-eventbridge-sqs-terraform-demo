variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "event_bus_name" {
  description = "Name of the shared event bus. This name is the contract that the product stacks look up."
  type        = string
  default     = "async-demo"
}
