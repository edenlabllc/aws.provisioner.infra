variable "AWS_REGION" {
  description = "The region Terraform deploys your instance"
  type        = string
  validation {
    condition = length(var.AWS_REGION) > 0
    error_message = "The AWS_REGION variable variable is not be empty."
  }
}

variable "AWS_ACCESS_KEY_ID" {
  type    = string
  validation {
    condition = length(var.AWS_ACCESS_KEY_ID) > 0
    error_message = "The AWS_ACCESS_KEY_ID variable is not be empty."
  }
}

variable "AWS_SECRET_ACCESS_KEY" {
  type    = string
  validation {
    condition = length(var.AWS_SECRET_ACCESS_KEY) > 0
    error_message = "The AWS_SECRET_ACCESS_KEY variable is not be empty."
  }
}

variable "ami_image_owner" {
  default     = "288509344804"
  description = "List of AMI owners to limit search"
  type        = string
}

variable "cidr_public_subnet" {
  default     = "10.1.0.0/24"
  description = "CIDR block for the public subnet"
  type        = string
}

variable "cidr_private_subnet" {
  default     = "10.1.1.0/24"
  description = "CIDR block for the private subnet"
  type        = string
}

variable "cidr_vpc" {
  default     = "10.1.0.0/16"
  description = "CIDR block for the VPC"
  type        = string
}

variable "instance_data_disk_size" {
  default     = 200
  description = "Specific instance data disk size for project"
  type        = number
}

variable "instance_ingress_ports" {
  default = [
    {
      host_port = 80
    },
    {
      host_port = 443
    }
  ]
  description = "Specific instance ingress ports for project"
  type = list(object({
    host_port = number
  }))
}

variable "instance_type" {
  default     = "t3.2xlarge"
  description = "Instance type to use for the instance"
  type        = string
}

variable "instance_with_private_network" {
  default     = false
  description = "Enable|Disable private network"
  type        = bool
}

variable "project_environment" {
  default     = "develop"
  description = "Environment"
  type        = string
}

variable "project_organization" {
  default     = "edenlabllc"
  description = "Organization"
  type        = string
}

variable "project_name" {
  default     = "kodjin"
  description = "Project name"
  type        = string
}

variable "project_version" {
  default     = "v4.4.0"
  description = "SemVer2 project version"
  type        = string
}

variable "ssh_username" {
  default     = "ec2-user"
  description = "The user name for access via SSH to instance"
  type        = string
}
