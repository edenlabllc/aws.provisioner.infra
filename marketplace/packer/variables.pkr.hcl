variable "aws_access_key_id" {
  default = env("AWS_ACCESS_KEY_ID")
  sensitive = true
  type    = string
}

variable "aws_base_image_filter" {
  default = "al2023-ami-2023.4.20240429.0-kernel-6.1-x86_64"
  type    = string
}

variable "aws_instance_launch_block_device" {
  default = {
    device_name = "/dev/xvda"
    volume_size = 10
  }
  type = map(string)
}

variable "aws_instance_ssh_username" {
  default = "ec2-user"
  type    = string
}

variable "aws_instance_type" {
  default = "t3.2xlarge"
  type    = string
}

variable "aws_region" {
  default = env("AWS_REGION")
  type    = string
}

variable "aws_secret_access_key" {
  default = env("AWS_SECRET_ACCESS_KEY")
  sensitive = true
  type    = string
}

variable "aws_skip_create_ami" {
  default = false
  type    = bool
}

variable "project_environment" {
  default = "develop"
  type    = string
}

variable "project_env_variables" {
  default = {
    LOKI_STACK_ALERTMANAGER_SLACK_API_URL = "https://hooks.slack.com/services/XXXXXXXXXXXX"
    SMTP_USERNAME                         = "notifications@example.com"
    SMTP_PASSWORD                         = "XXXXXXXXXXXX"
    FIXTURES_GIT_PAT                      = "ghp_XXXXXXXXXXXX"
    ERROR_MAIL_RECEIVER                   = "notifications-XXXXXXXXXXXX@example.slack.com"
  }
  sensitive = true
  type      = map(string)
}

variable "project_organization" {
  default = "edenlabllc"
  type    = string
}

variable "project_name" {
  default = "kodjin"
  type    = string
}

variable "project_version" {
  default = "v4.4.0"
  type    = string
}

variable "rmk_root_domain" {
  default = "localhost"
  type    = string
}

variable "rmk_version" {
  default = "latest"
  type    = string
}
