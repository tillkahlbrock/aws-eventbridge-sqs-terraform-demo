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

  backend "s3" {
    bucket       = "async-demo-terraform-state"
    key          = "platform/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn     = var.deploy_role_arn
    session_name = "terraform-platform-stack"
  }
}
