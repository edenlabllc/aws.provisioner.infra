variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "root_domain" {
  type = string
}

variable "terraform_bucket_name" {
  type = string
}

variable "terraform_bucket_key" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "vpc_private_subnets" {
  type    = list(string)
  default = ["10.1.0.0/22", "10.1.4.0/22", "10.1.8.0/22"]
}

variable "vpc_public_subnets" {
  type    = list(string)
  default = ["10.1.20.0/24", "10.1.30.0/24", "10.1.40.0/24"]
}

variable "sg_all_cidr" {
  type    = list(string)
  default = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "sg_database_cidr_ingress" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "sg_database_cidr_egress" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "worker_groups" {
}

variable "k8s_master_usernames" {
  type      = list(string)
  default   = []
  sensitive = true
}

variable "k8s_users" {
  type    = map(set(string))
  default = {}
}

variable "k8s_cluster_version" {
  type    = string
  default = "1.19"
}

variable "aws_account_id" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone" {
  type    = string
  default = "edenlab.dev"
}

variable "cloudflare_ns_provision_enabled" {
  type    = bool
  default = true
}

variable "db_enabled" {
  type    = bool
  default = false
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "11.10"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.small"
}

variable "db_allocated_storage" {
  type    = string
  default = "20"
}

variable "db_parameter_group" {
  type    = string
  default = "postgres11"
}

variable "db_major_engine_version" {
  type    = string
  default = "11"
}

variable "db_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "db_port" {
  type    = string
  default = "5432"
}

variable "db_maintenance_window" {
  type    = string
  default = "Mon:00:00-Mon:03:00"
}

variable "db_backup_window" {
  type    = string
  default = "03:00-06:00"
}

variable "db_backup_retention_period" {
  type    = string
  default = "0"
}

variable "kubernetes_storage_class_name" {
  type        = string
  default     = "gp2"
  description = "The storage class provisioner name"
}

variable "bastion_enabled" {
  type = bool
}

variable "iaas_delivery" {
  description = "Deploy Kubernetes on EC2 Instances"
  type        = bool
  default     = false
}

variable "acm_provisioning" {
  description = "Provision public ACM Certificates"
  type        = bool
  default     = true
}

variable "iaas_aws_elb_api_port" {
  description = "Port for AWS ELB"
  type        = number
  default     = 6443
}

variable "iaas_k8s_secure_api_port" {
  description = "Secure Port of K8S API Server"
  type        = number
  default     = 6443
}

variable "iaas_inventory_file" {
  description = "Where to store the generated inventory file"
  type        = string
  default     = "inventory.ini"
}

variable "iaas_instance_groups" {
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
  default = []
}

variable "iaas_ami_id" {
  description = "AMI ID for ec2 instance iaas"
  type        = string
  default     = "ami-0c24aada583dfe870"
}

variable "iaas_user_name_for_nodes" {
  description = "Username for Kubernetes nodes"
  type        = string
  default     = "ubuntu"
}

variable "aws_lb_controller_role_enabled" {
  description = "Create IAM Role for AWS LB Controller"
  type        = bool
  default     = true
}

variable "aws_lb_controller_sa_name" {
  description = "Service account name and namespace for load balancer controller"
  type        = string
  default     = "kube-system:aws-load-balancer-controller"
}

variable "cluster_autoscaler_roles_enabled" {
  description = "Create IAM Role for cluster autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_sa_name" {
  description = "Service account name and namespace for cluster autoscaler"
  type        = string
  default     = "kube-system:cluster-autoscaler-aws-cluster-autoscaler"
}

variable "ebs_csi_controller_roles_enabled" {
  description = "Create IAM Role for EBS CSI Driver"
  type        = bool
  default     = true
}

variable "ebs_csi_controller_sa_name" {
  description = "Service account name and namespace for EBS csi driver"
  type        = string
  default     = "kube-system:ebs-csi-controller"
}

variable "ebs_snapshot_provision_sa_name" {
  description = "Service account name and namespace for EBS snapshot provision"
  type        = string
  default     = "kube-system:ebs-snapshot-provision-operator"
}

variable "external_dns_role_enabled" {
  description = "Create IAM Role for External DNS"
  type        = bool
  default     = true
}

variable "external_dns_sa_name" {
  description = "Service account name and namespace for external dns"
  type        = string
  default     = "kube-system:external-dns"
}

variable "cluster_log_retention_period" {
  description = "Number of days to retain log events"
  type        = number
  default     = 14
}

variable "cluster_log_types" {
  description = "A list of the desired control plane logs to enable"
  type        = list(string)
  default     = []
}
