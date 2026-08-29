# Stack: order-service, the event producer. Owner: Product Team A.
# Deploys into: sender workload account.
#
# The platform provider is read-only. The stack uses it to resolve the shared
# event bus by name. It creates nothing in the platform account.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = var.deploy_role_arn
    session_name = "terraform-order-service-stack"
  }
}

provider "aws" {
  alias  = "platform"
  region = var.region

  assume_role {
    role_arn     = var.platform_read_role_arn
    session_name = "terraform-order-service-lookup"
  }
}
