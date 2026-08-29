# Stack: platform. Owner: Platform Team.
# Deploys into: platform account.
#
# The pipeline holds base credentials and assumes the deploy role of this stack.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The pipeline supplies bucket, key and region through -backend-config.
  backend "s3" {}
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = var.deploy_role_arn
    session_name = "terraform-platform-stack"
  }
}
