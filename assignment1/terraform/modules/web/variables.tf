variable "aws_region" {
  description = "Region to build in. LocalStack ignores it, real AWS does not."
  type        = string
  default     = "us-east-1"
}
variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "acs730-a1"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project))
    error_message = "project: 3-24 lowercase letters, digits, hyphens, starting with a letter."
  }
}
variable "owner" {
  description = "Your Seneca username. Tagged onto everything. No default on purpose."
  type        = string
}
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, for example 10.42.0.0/16."
  }
}
variable "public_subnets" {
  description = "Public subnets to create, keyed by a short stable name."
  type = map(object({
    cidr_block = string
    az_index   = number
  }))
  default = {
    a = { cidr_block = "10.42.1.0/24", az_index = 0 }
    b = { cidr_block = "10.42.2.0/24", az_index = 1 }
  }
}
variable "ingress_rules" {
  description = "Ingress rules for the web security group, rendered by a dynamic block."
  type = list(object({
    description = string
    port        = number
    cidr_blocks = list(string)
  }))
  default = [
    { description = "HTTP from anywhere", port = 80, cidr_blocks = ["0.0.0.0/0"] },
  ]
}
variable "instance_type" {
  description = "Instance type for the web server."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Stay small: t3.micro or t3.small. The term budget is $50 in total."
  }
}

variable "environment" {
  description = "Which environment this deployment is: dev, staging or prod. Used in names and tags so the three never collide."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "ssm_parameter_name" {
  description = "Name of the SSM parameter holding this environment's app secret, e.g. /acs730/dev/db_password. Created out of band; Terraform only reads it."
  type        = string
}

variable "cpu_alarm_threshold" {
  description = "Average CPU percent at which the CloudWatch alarm fires."
  type        = number
  default     = 50
}
