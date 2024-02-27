variable "inventory_file" {
  description = "Where to store the generated inventory file"
  type        = string
}

variable "instance_groups" {
  description = "Add"
  type = list(object({
    name             = string
    instance_type    = string
    count            = number
    type             = string
    root_volume_size = number
    root_volume_type = string
    labels           = map(string)
    taints           = map(string)
    ebs_volumes = list(object({
      delete_on_termination = bool
      device_name           = string
      encrypted             = bool
      volume_type           = string
      volume_size           = number
    }))
  }))
}

variable "ami_id" {
  description = "AMI ID for ec2 instance iaas"
  type        = string
}

variable "user_name_for_nodes" {
  type        = string
  description = "Username for nodes"
  default     = "ubuntu"
}

variable "aws_elb_api_port" {
  description = "Port for AWS ELB"
  type        = number
  default     = 6443
}

variable "k8s_secure_api_port" {
  description = "Secure Port of K8S API Server"
  type        = number
  default     = 6443
}

variable "name" {
  type = string
}

variable "bastion_instance_public_ip" {
  type        = string
  description = "Bastion instance public ip"
}

variable "vpc_module" {
  type        = any
  description = "VPC Module"
}

variable "key_pair_bastion" {
  type        = string
  description = "Key pair name for instances"
}

variable "bastion_sg_id" {
  type        = string
  description = "Security group which allows ssh connectivity from bastion"
}

variable "ssh_private_key_name_bastion" {
  type        = string
  description = "SSH Private key name"
}

variable "aws_availability_zones" {
  type        = any
  description = "List of availability zones"
}

variable "route53_hosted_zone_id" {
  type        = string
  description = "Hosted zone id"
}

variable "route53_hosted_zone_fqdn" {
  type        = string
  description = "Hosted zone domain name"
}

variable "kube_api_record_name" {
  type        = string
  default     = "kube-api"
  description = "Kube API record name"
}

variable "kube_api_record_type" {
  type        = string
  default     = "A"
  description = "Kube API record type"
}

variable "kube_api_target_health_evaluation" {
  type        = bool
  default     = true
  description = "Kube API route 53 target health evaluation"
}
