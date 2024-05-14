terraform {
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "~>4.42.0"
    }

    local = {
      source  = "registry.terraform.io/hashicorp/local"
      version = "~>2.5.0"
    }

    null = {
      source  = "registry.terraform.io/hashicorp/null"
      version = "~>3.2.2"
    }
  }

  required_version = ">= 0.14.8"
}
