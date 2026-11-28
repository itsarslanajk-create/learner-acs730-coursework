terraform {
  required_version = ">= 1.10.0"
  backend "s3" {
    bucket       = "acs730-tfstate-073376610117"
    key          = "lab6/terraform.tfstate"
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
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_count" {
  description = "How many web servers. Two proves the inventory is dynamic."
  type        = number
  default     = 2
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "web" {
  name        = "acs730-lab6-sg"
  description = "ACS730 Lab 6 web servers -- port 80 in, nothing else"

  # No port 22 rule on purpose: Ansible arrives over SSM (outbound).
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "acs730-lab6-sg", Project = "acs730", Lab = "lab6" }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]

  # Lets the SSM agent register: the reason no inbound port is needed.
  iam_instance_profile = "LabInstanceProfile"

  # The contract with Ansible: the inventory finds servers by these tags.
  tags = {
    Name    = "acs730-lab6-web-${count.index}"
    Project = "acs730"
    Lab     = "lab6"
    Role    = "web"
  }
}

output "web_public_ips" {
  value = aws_instance.web[*].public_ip
}

output "first_web_public_ip" {
  value = aws_instance.web[0].public_ip
}

output "web_instance_ids" {
  value = aws_instance.web[*].id
}

output "security_group_id" {
  value = aws_security_group.web.id
}
