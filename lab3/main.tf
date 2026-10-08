terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "acs730-tfstate-073376610117"
    key          = "lab3/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.region
}

resource "aws_security_group" "demo" {
  name_prefix = "acs730-lab3-demo-"
  description = "ACS730 Lab 3 pipeline demo"

  tags = {
    Name   = "acs730-lab3-demo"
    Course = "ACS730"
    Lab    = "3"
    Owner  = "pipeline"
  }
}
