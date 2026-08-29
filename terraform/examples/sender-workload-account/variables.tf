variable "region" {
  description = "AWS region of the demo. All three accounts use the same region."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile of the sender workload account. Leave it null to authenticate through environment variables."
  type        = string
  default     = null
}

variable "event_bus_arn" {
  description = "ARN of the shared event bus. Copy this value from the platform deployment output."
  type        = string
}

variable "policy_name" {
  description = "Name of the IAM policy that allows publishing to the shared event bus."
  type        = string
  default     = "async-demo-put-events"
}

variable "create_demo_role" {
  description = "Create an assumable demo role for manual test events."
  type        = bool
  default     = true
}
