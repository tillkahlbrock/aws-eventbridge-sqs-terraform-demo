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
  profile = var.platform_profile
}

provider "aws" {
  alias   = "fulfillment"
  region  = var.region
  profile = var.fulfillment_profile
}
