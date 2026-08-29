# Service: persistence-service, the event consumer. Owner: Product Team B.
# Deploys into: platform account and receiver workload account.
# This root needs two provider configurations. An EventBridge rule must be created
# on the account that owns the event bus.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  alias   = "platform"
  region  = var.region
  profile = var.platform_aws_profile
}

provider "aws" {
  alias   = "receiver"
  region  = var.region
  profile = var.receiver_aws_profile
}
