# Stack: fulfillment-service, the event consumer. Owner: Product Team B.
# Deploys into: platform account and receiver workload account.
#
# The platform provider assumes the administrative deploy role of the Platform
# Team. A scoped role per stack is a later improvement. See docs/concept.md.

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
  alias  = "platform"
  region = var.region

  assume_role {
    role_arn     = var.platform_deploy_role_arn
    session_name = "terraform-fulfillment-service-subscription"
  }
}

provider "aws" {
  alias  = "receiver"
  region = var.region

  assume_role {
    role_arn     = var.deploy_role_arn
    session_name = "terraform-fulfillment-service-stack"
  }
}
