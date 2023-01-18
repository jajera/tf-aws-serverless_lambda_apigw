terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.48.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Generate random string as prefix to all resources
resource "random_string" "prefix" {
  length  = 5
  special = false
  upper   = true
  lower   = false
  numeric = false
}