terraform {
  required_version = ">= 1.10"

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

resource "aws_s3_bucket" "demo" {
  bucket_prefix = "acs730-lab3-demo-"

  tags = {
    Course = "ACS730"
    Lab    = "3"
    Owner  = "pipeline"
  }
}
