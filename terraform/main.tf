# Backend and provider configuration
terraform {
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

provider "local" {
}

# required in case of empty cloudflare api token to bypass provider validation cloudflare.
locals {
  null_cloudflare_api_token = "123456789-password1234567890123456-12345"
}

provider "cloudflare" {
  api_token = var.cloudflare_ns_provision_enabled ? var.cloudflare_api_token : local.null_cloudflare_api_token
}

# VPC configuration
data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "${var.name}-${var.iaas_delivery ? "k8s" : "eks"}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "${var.name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.vpc_private_subnets
  public_subnets       = var.vpc_public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    Environment                                   = terraform.workspace
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# Bastion configuration
locals {
  ssh_user_bastion                    = "ec2-user"
  ssh_private_key_name_bastion        = "${var.name}-private-key-bastion.pem"
  ssh_private_key_destination_bastion = "/home/${local.ssh_user_bastion}/.ssh/${local.ssh_private_key_name_bastion}"
  ssh_private_key_permissions         = "0400"
}

# always create bastion tls_private_key
resource "tls_private_key" "tls_private_key_bastion" {
  algorithm = "RSA"
}

resource "local_file" "local_file_bastion" {
  count = var.bastion_enabled ? 1 : 0

  sensitive_content = tls_private_key.tls_private_key_bastion.private_key_pem
  filename          = pathexpand("~/.ssh/${local.ssh_private_key_name_bastion}")
  file_permission   = local.ssh_private_key_permissions
}

# always create bastion key-pair
module "key_pair_bastion" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 1.0"

  key_name_prefix = "${var.name}-key-pair-bastion-"
  public_key      = tls_private_key.tls_private_key_bastion.public_key_openssh
}

resource "aws_security_group" "sg_bastion" {
  count = var.bastion_enabled ? 1 : 0

  name_prefix = "${var.name}-sg-bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = terraform.workspace
    Name        = "${var.name}-sg-bastion"
  }
}

resource "aws_instance" "instance_bastion" {
  count = var.bastion_enabled ? 1 : 0

  ami                    = "ami-0865a7423ddc6317c" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type          = "t3.micro"
  key_name               = module.key_pair_bastion.key_pair_key_name
  monitoring             = true
  vpc_security_group_ids = aws_security_group.sg_bastion.*.id
  subnet_id              = module.vpc.public_subnets[0]

  provisioner "file" {
    source      = local_file.local_file_bastion[0].filename
    destination = local.ssh_private_key_destination_bastion

    connection {
      type        = "ssh"
      user        = local.ssh_user_bastion
      private_key = file(local_file.local_file_bastion[0].filename)
      host        = self.public_dns
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod ${local.ssh_private_key_permissions} ${local.ssh_private_key_destination_bastion}",
    ]

    connection {
      type        = "ssh"
      user        = local.ssh_user_bastion
      private_key = file(local_file.local_file_bastion[0].filename)
      host        = self.public_dns
    }
  }

  tags = {
    Environment = terraform.workspace
    Name        = "${var.name}-bastion"
  }
}

# EKS configuration
resource "aws_security_group" "sg_all_worker_management" {
  name_prefix = "${var.name}-sg-all-worker-management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.sg_all_cidr
    security_groups = aws_security_group.sg_bastion.*.id
  }

  tags = {
    Environment = terraform.workspace
    Name        = "${var.name}-sg-all-worker-management"
  }
}

resource "aws_security_group" "sg_database_allow" {
  count       = var.db_enabled ? 1 : 0
  name_prefix = "${var.name}-sg-database-allow"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.sg_database_cidr_ingress
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.sg_database_cidr_egress
  }

  tags = {
    Environment = terraform.workspace
    Name        = "${var.name}-sg-database-allow"
  }
}

resource "aws_iam_role" "cluster-autoscaler" {
  count = var.cluster_autoscaler_roles_enabled ? 1 : 0
  name  = "${var.name}-cluster-autoscaler"
  assume_role_policy = templatefile("${path.module}/templates/sa-iam-roles-trust-policy.tpl", {
    oidc_issuer_arn      = module.eks[0].oidc_provider_arn,
    oidc_issuer_id       = basename(module.eks[0].cluster_oidc_issuer_url)
    service_account_name = var.cluster_autoscaler_sa_name
    region               = var.region
  })
}

resource "aws_iam_policy" "cluster-autoscaler" {
  count  = var.cluster_autoscaler_roles_enabled ? 1 : 0
  name   = "${var.name}-AWSClusterAutoscalerIAMPolicy"
  policy = templatefile("${path.module}/templates/cluster-autoscaler-policy.tpl", {})
}

resource "aws_iam_role_policy_attachment" "cluster-autoscaler" {
  count      = var.cluster_autoscaler_roles_enabled ? 1 : 0
  policy_arn = aws_iam_policy.cluster-autoscaler[0].arn
  role       = aws_iam_role.cluster-autoscaler[0].name
}

resource "aws_iam_role" "external-dns" {
  count = var.external_dns_role_enabled ? 1 : 0
  name  = "${var.name}-external-dns"
  assume_role_policy = templatefile("${path.module}/templates/sa-iam-roles-trust-policy.tpl", {
    oidc_issuer_arn      = module.eks[0].oidc_provider_arn,
    oidc_issuer_id       = basename(module.eks[0].cluster_oidc_issuer_url)
    service_account_name = var.external_dns_sa_name
    region               = var.region
  })
}

resource "aws_iam_policy" "external-dns" {
  count  = var.external_dns_role_enabled ? 1 : 0
  name   = "${var.name}-AllowExternalDNSUpdates"
  policy = templatefile("${path.module}/templates/external-dns-policy.tpl", {})
}

resource "aws_iam_role_policy_attachment" "external-dns" {
  count      = var.external_dns_role_enabled ? 1 : 0
  policy_arn = aws_iam_policy.external-dns[0].arn
  role       = aws_iam_role.external-dns[0].name
}

resource "aws_iam_role" "ebs-csi" {
  count = var.ebs_csi_controller_roles_enabled ? 1 : 0
  name  = "${var.name}-ebs-csi-controller"
  assume_role_policy = templatefile("${path.module}/templates/sa-iam-roles-trust-policy.tpl", {
    oidc_issuer_arn      = module.eks[0].oidc_provider_arn,
    oidc_issuer_id       = basename(module.eks[0].cluster_oidc_issuer_url)
    service_account_name = var.ebs_csi_controller_sa_name
    region               = var.region
  })
}

resource "aws_iam_policy" "ebs-csi" {
  count  = var.ebs_csi_controller_roles_enabled ? 1 : 0
  name   = "${var.name}-AWSEbsCSIControllerIAMPolicy"
  policy = templatefile("${path.module}/templates/ebs-csi-controller-policy.tpl", {})
}

resource "aws_iam_policy" "ebs-csi-kms-key" {
  count  = var.ebs_csi_controller_roles_enabled ? 1 : 0
  name   = "${var.name}-AWSEbsCSIKMSKeyIAMPolicy"
  policy = templatefile("${path.module}/templates/ebs-csi-kms-key-policy.tpl", {})
}

resource "aws_iam_role_policy_attachment" "ebs-csi" {
  count      = var.ebs_csi_controller_roles_enabled ? 1 : 0
  policy_arn = aws_iam_policy.ebs-csi[0].arn
  role       = aws_iam_role.ebs-csi[0].name
}

resource "aws_iam_role_policy_attachment" "ebs-csi-kms-key" {
  count      = var.ebs_csi_controller_roles_enabled ? 1 : 0
  policy_arn = aws_iam_policy.ebs-csi-kms-key[0].arn
  role       = aws_iam_role.ebs-csi[0].name
}

resource "aws_iam_role" "ebs-snapshot-provision" {
  count = var.ebs_csi_controller_roles_enabled ? 1 : 0
  name  = "${var.name}-ebs-snapshot-provision"
  assume_role_policy = templatefile("${path.module}/templates/sa-iam-roles-trust-policy.tpl", {
    oidc_issuer_arn      = module.eks[0].oidc_provider_arn,
    oidc_issuer_id       = basename(module.eks[0].cluster_oidc_issuer_url)
    service_account_name = var.ebs_snapshot_provision_sa_name
    region               = var.region
  })
}

resource "aws_iam_policy" "ebs-snapshot-provision" {
  count  = var.ebs_csi_controller_roles_enabled ? 1 : 0
  name   = "${var.name}-AWSEbsSnapshotProvisionIAMPolicy"
  policy = templatefile("${path.module}/templates/ebs-snapshot-provision-policy.tpl", {})
}

resource "aws_iam_role_policy_attachment" "ebs-snapshot-provision" {
  count      = var.ebs_csi_controller_roles_enabled ? 1 : 0
  policy_arn = aws_iam_policy.ebs-snapshot-provision[0].arn
  role       = aws_iam_role.ebs-snapshot-provision[0].name
}

resource "aws_iam_role" "load-balancer-controller" {
  count = var.aws_lb_controller_role_enabled ? 1 : 0
  name  = "${var.name}-aws-load-balancer-controller"
  assume_role_policy = templatefile("${path.module}/templates/sa-iam-roles-trust-policy.tpl", {
    oidc_issuer_arn      = module.eks[0].oidc_provider_arn,
    oidc_issuer_id       = basename(module.eks[0].cluster_oidc_issuer_url)
    service_account_name = var.aws_lb_controller_sa_name
    region               = var.region
  })
}

resource "aws_iam_policy" "load-balancer-controller" {
  count  = var.aws_lb_controller_role_enabled ? 1 : 0
  name   = "${var.name}-aws-load-balancer-controller"
  policy = templatefile("${path.module}/templates/aws-load-balancer-controller-policy.tpl", {})
}

resource "aws_iam_role_policy_attachment" "load-balancer-controller" {
  count      = var.aws_lb_controller_role_enabled ? 1 : 0
  policy_arn = aws_iam_policy.load-balancer-controller[0].arn
  role       = aws_iam_role.load-balancer-controller[0].name
}

resource "aws_iam_role" "eks-cluster" {
  name               = "${var.name}-eks-cluster"
  assume_role_policy = templatefile("${path.module}/templates/eks-cluster-policy.tpl", {})
}

resource "aws_iam_group" "ops" {
  name = "${var.name}-ops"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_iam_group_policy_attachment" "AmazonEKSClusterPolicy" {
  group      = aws_iam_group.ops.name
  policy_arn = aws_iam_role_policy_attachment.AmazonEKSClusterPolicy.policy_arn
}

resource "aws_iam_group_policy_attachment" "AmazonEKSServicePolicy" {
  group      = aws_iam_group.ops.name
  policy_arn = aws_iam_role_policy_attachment.AmazonEKSServicePolicy.policy_arn
}

module "eks" {
  count                           = !var.iaas_delivery ? 1 : 0
  source                          = "terraform-aws-modules/eks/aws"
  cluster_name                    = local.cluster_name
  subnets                         = module.vpc.private_subnets
  version                         = "16.1.0"
  cluster_version                 = var.k8s_cluster_version
  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true
  enable_irsa                     = true
  write_kubeconfig                = false
  cluster_log_retention_in_days   = var.cluster_log_retention_period
  cluster_enabled_log_types       = var.cluster_log_types

  tags = {
    Environment = terraform.workspace
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  vpc_id = module.vpc.vpc_id

  worker_groups                        = var.worker_groups
  worker_additional_security_group_ids = [aws_security_group.sg_all_worker_management.id]
  workers_group_defaults = {
    # only applied to new instances
    key_name = module.key_pair_bastion.key_pair_key_name
  }

  map_roles = [{
    rolearn  = aws_iam_role.eks-cluster.arn
    username = aws_iam_role.eks-cluster.name
    groups   = [aws_iam_group.ops.name]
  }]

  map_users = concat([for v in var.k8s_master_usernames : {
    userarn  = "arn:aws:iam::${var.aws_account_id}:user/${v}"
    username = v
    groups   = ["system:masters"]
    }],
    flatten([for group, users in var.k8s_users : [for user in users : {
      userarn  = "arn:aws:iam::${var.aws_account_id}:user/${user}"
      username = user
      groups   = ["system:${group}"]
  }]]))
}

data "aws_eks_cluster_auth" "cluster" {
  count = !var.iaas_delivery ? 1 : 0
  name  = module.eks[0].cluster_id
}

provider "kubernetes" {
  host                   = try(module.eks[0].cluster_endpoint, null)
  token                  = try(data.aws_eks_cluster_auth.cluster[0].token, null)
  cluster_ca_certificate = try(base64decode(module.eks[0].cluster_certificate_authority_data), null)
}

# RDS configuration
locals {
  db_name = var.name
}

module "db" {
  count = var.db_enabled ? 1 : 0

  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.0"

  identifier = local.db_name

  engine            = var.db_engine
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_encrypted = false

  # kms_key_id        = "arm:aws:kms:<region>:<account id>:key/<kms key id>"
  name = replace(var.name, "-", "")

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  username = replace(var.name, "-", "")

  password = var.db_password
  port     = var.db_port

  vpc_security_group_ids = [aws_security_group.sg_database_allow[0].id]

  maintenance_window = var.db_maintenance_window
  backup_window      = var.db_backup_window

  # disable backups to create DB faster
  backup_retention_period = var.db_backup_retention_period

  tags = {
    Environment = terraform.workspace
    Owner       = local.db_name
  }

  #enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # DB subnet group
  subnet_ids = module.vpc.public_subnets

  # DB parameter group
  family = var.db_parameter_group

  # DB option group
  major_engine_version = var.db_major_engine_version

  # Snapshot name upon DB deletion
  final_snapshot_identifier = local.db_name

  # Database Deletion Protection
  deletion_protection = false
  # Bool to control if instance is publicly accessible
  publicly_accessible = true

  skip_final_snapshot = true
}

# DNS hosted zone configuration
resource "aws_route53_zone" "hosted_zone" {
  name          = "${var.root_domain}."
  comment       = "Managed by Route53 or CloudFlare API."
  force_destroy = true
  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Route53 or CloudFlare API"
  }
}

data "cloudflare_zones" "cf_zone" {
  count = var.cloudflare_ns_provision_enabled ? 1 : 0
  filter {
    name = var.cloudflare_zone
  }
}

resource "cloudflare_record" "cf_ns" {
  # For count or for_each, instructions expect keys of the map (or all the values in the case of a set of strings)
  # must be known values, or you will get an error message: "that has dependencies that cannot be determined before apply".
  # By default for aws_route53_zone provide 4 name servers.
  count   = var.cloudflare_ns_provision_enabled ? 4 : 0
  zone_id = data.cloudflare_zones.cf_zone[0].zones[0].id
  name    = var.root_domain
  type    = "NS"
  ttl     = "300"
  proxied = "false"
  value   = aws_route53_zone.hosted_zone.name_servers[count.index]
}

# Certificate configuration
module "acm" {
  count   = var.acm_provisioning ? 1 : 0
  source  = "terraform-aws-modules/acm/aws"
  version = "~> v2.14.0"

  domain_name = aws_route53_zone.hosted_zone.name
  zone_id     = aws_route53_zone.hosted_zone.id

  subject_alternative_names = [
    "*.${aws_route53_zone.hosted_zone.name}",
  ]

  tags = {
    Environment = terraform.workspace
    Name        = aws_route53_zone.hosted_zone.name
  }

  wait_for_validation = false
}

# Enable allow volume expansion
# PersistentVolumes can be configured to be expandable.
# AllowVolumeExpansion when set to true, allows the users to resize the volume by editing the corresponding PVC object.
data "kubernetes_storage_class" "this" {
  count = !var.iaas_delivery ? 1 : 0
  metadata {
    name = var.kubernetes_storage_class_name
  }

  depends_on = [
    module.eks,
  ]
}

provider "kubectl" {
  host                   = try(module.eks[0].cluster_endpoint, null)
  token                  = try(data.aws_eks_cluster_auth.cluster[0].token, null)
  cluster_ca_certificate = try(base64decode(module.eks[0].cluster_certificate_authority_data), null)
  load_config_file       = false
}

resource "kubectl_manifest" "gp2" {
  count     = !var.iaas_delivery ? 1 : 0
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${data.kubernetes_storage_class.this[0].metadata[0].name}
parameters:
  fsType: ${data.kubernetes_storage_class.this[0].parameters.fsType}
  type: ${data.kubernetes_storage_class.this[0].parameters.type}
provisioner: ${data.kubernetes_storage_class.this[0].storage_provisioner}
reclaimPolicy: ${data.kubernetes_storage_class.this[0].reclaim_policy}
volumeBindingMode: ${data.kubernetes_storage_class.this[0].volume_binding_mode}
allowVolumeExpansion: true
YAML

  depends_on = [
    module.eks,
  ]
}

# Controllers provision for eks
provider "helm" {
  kubernetes {
    host                   = try(module.eks[0].cluster_endpoint, null)
    token                  = try(data.aws_eks_cluster_auth.cluster[0].token, null)
    cluster_ca_certificate = try(base64decode(module.eks[0].cluster_certificate_authority_data), null)
  }
}

module "iaas" {
  source = "./modules/iaas"
  count  = var.iaas_delivery ? 1 : 0

  name                         = local.cluster_name
  vpc_module                   = module.vpc
  key_pair_bastion             = module.key_pair_bastion.key_pair_key_name
  ssh_private_key_name_bastion = local.ssh_private_key_name_bastion
  bastion_instance_public_ip   = aws_instance.instance_bastion[0].public_ip
  bastion_sg_id                = aws_security_group.sg_all_worker_management.id
  aws_elb_api_port             = var.iaas_aws_elb_api_port
  k8s_secure_api_port          = var.iaas_k8s_secure_api_port
  instance_groups              = var.iaas_instance_groups
  ami_id                       = var.iaas_ami_id
  user_name_for_nodes          = var.iaas_user_name_for_nodes
  inventory_file               = var.iaas_inventory_file
  aws_availability_zones       = data.aws_availability_zones.available
  route53_hosted_zone_fqdn     = aws_route53_zone.hosted_zone.name
  route53_hosted_zone_id       = aws_route53_zone.hosted_zone.id
}
