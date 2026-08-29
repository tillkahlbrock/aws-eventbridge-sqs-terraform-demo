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
    key          = "consumers/fulfillment-service/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}

provider "aws" {
  alias   = "platform"
  region  = var.region
  profile = var.platform_profile
}

provider "aws" {
  alias   = "receiver"
  region  = var.region
  profile = var.receiver_profile
}
