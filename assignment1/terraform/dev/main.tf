terraform {
  required_version = ">= 1.10.0"

  # One bucket, one key per environment: their states never collide.
  backend "s3" {
    bucket       = "acs730-tfstate-073376610117"
    key          = "assignment1/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Course      = "ACS730"
      Assignment  = "assignment1"
      Environment = "dev"
    }
  }
}

# Same module, environment-specific values.
module "web" {
  source = "../modules/web"

  environment        = "dev"
  owner              = "aahmed441"
  instance_type      = "t3.micro"
  vpc_cidr           = "10.1.0.0/16"
  ssm_parameter_name = "/acs730/dev/db_password"

  public_subnets = {
    a = { cidr_block = "10.1.1.0/24", az_index = 0 }
    b = { cidr_block = "10.1.2.0/24", az_index = 1 }
  }
}

output "vpc_id" { value = module.web.vpc_id }
output "web_public_ip" { value = module.web.web_public_ip }
output "web_url" { value = module.web.web_url }
output "ssm_parameter_read" { value = module.web.ssm_parameter_read }
output "cpu_alarm_name" { value = module.web.cpu_alarm_name }
