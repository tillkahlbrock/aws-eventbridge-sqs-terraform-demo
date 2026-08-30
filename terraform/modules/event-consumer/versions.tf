terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"

      # An EventBridge rule must be created on the account that owns the event bus.
      # The SQS queues belong to the consumer's workload account.
      # The root module supplies both provider configurations.
      configuration_aliases = [aws.platform, aws.consumer]
    }
  }
}
