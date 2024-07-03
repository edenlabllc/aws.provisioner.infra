terraform {
  required_version = ">= 0.14.8, < 1.5.7"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "~>3.74.0"
    }
    local = {
      source  = "registry.terraform.io/hashicorp/local"
      version = "~>2.1.0"
    }
  }
}
