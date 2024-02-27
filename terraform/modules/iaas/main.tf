#### IAAS Implementation
module "aws-elb" {
  source = "../elb"

  aws_cluster_name      = var.name
  aws_vpc_id            = var.vpc_module.vpc_id
  aws_avail_zones       = slice(var.aws_availability_zones.names, 0, length(var.vpc_module.public_subnets_cidr_blocks) <= length(var.aws_availability_zones.names) ? length(var.vpc_module.public_subnets_cidr_blocks) : length(var.aws_availability_zones.names))
  aws_subnet_ids_public = var.vpc_module.public_subnets
  aws_elb_api_port      = var.aws_elb_api_port
  k8s_secure_api_port   = var.k8s_secure_api_port
}

locals {
  instance_groups = flatten([for k, v in var.instance_groups :
  [for s in range(v.count) : v]])
}

resource "aws_elb_attachment" "attach_master_nodes" {
  for_each = { for k, v in local.instance_groups : k => v if v.type == "control-plane" }
  elb      = module.aws-elb.aws_elb_api_id
  instance = aws_instance.k8s-node["${each.key}:${each.value.type}"].id
}

resource "aws_instance" "k8s-node" {
  for_each      = { for k, v in local.instance_groups : "${k}:${v.type}" => v }
  ami           = "ami-000e50175c5f86214"
  instance_type = each.value.instance_type
  subnet_id     = element(var.vpc_module.private_subnets, tonumber(substr(each.key, 0, 1)))

  vpc_security_group_ids = [aws_security_group.sg_node.id, var.bastion_sg_id]

  root_block_device {
    volume_size = each.value.root_volume_size
    volume_type = each.value.root_volume_type
  }

  dynamic "ebs_block_device" {
    for_each = { for ebs in each.value.ebs_volumes : ebs.device_name => ebs }
    content {
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", null)
      device_name           = ebs_block_device.value.device_name
      encrypted             = lookup(ebs_block_device.value, "encrypted", null)
      iops                  = lookup(ebs_block_device.value, "iops", null)
      kms_key_id            = lookup(ebs_block_device.value, "kms_key_id", null)
      snapshot_id           = lookup(ebs_block_device.value, "snapshot_id", null)
      volume_size           = lookup(ebs_block_device.value, "volume_size", null)
      volume_type           = lookup(ebs_block_device.value, "volume_type", null)
    }
  }

  iam_instance_profile = each.value.type == "control-plane" ? aws_iam_instance_profile.kube_control_plane.name : (
    each.value.type == "kube-node" ? aws_iam_instance_profile.kube-worker.name : null
  )
  key_name = var.key_pair_bastion

  tags = {
    Name                                = "${var.name}-${each.value.name}-${each.value.type}"
    "kubernetes.io/cluster/${var.name}" = "member"
    Role                                = "${each.value.name}"
  }
}

resource "aws_security_group" "sg_node" {
  name_prefix = "${var.name}-sg-k8s-node"
  vpc_id      = var.vpc_module.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.vpc_module.private_subnets_cidr_blocks, var.vpc_module.public_subnets_cidr_blocks)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = terraform.workspace
    Name        = "${var.name}-sg-k8s-node"
  }
}

locals {
  list_master  = [for k, v in aws_instance.k8s-node : v if length(split("control-plane", k)) > 1]
  list_workers = [for k, v in aws_instance.k8s-node : v if length(split("kube-node", k)) > 1]
  list_etcd    = [for k, v in aws_instance.k8s-node : v if length(split("etcd", k)) > 1]
  template_file_init = templatefile("${path.module}/templates/inventory.tpl", {
    public_ip_address_bastion        = join("\n", formatlist("bastion ansible_host=%s", var.bastion_instance_public_ip))
    cluster_name                     = join("\n", formatlist("cluster_name=%s", var.route53_hosted_zone_fqdn))
    additional_variables_for_bastion = join("\n", formatlist("ansible_user=%s", "ec2-user"))
    additional_variables_for_all     = join("\n", formatlist("ansible_user=%s\nansible_ssh_private_key_file=%s", var.user_name_for_nodes, pathexpand("~/.ssh/${var.ssh_private_key_name_bastion}")))
    connection_strings_master        = join("\n", formatlist("%s ansible_host=%s", local.list_master[*].private_dns, local.list_master[*].private_ip))
    connection_strings_nodes         = join("\n", formatlist("%s ansible_host=%s", local.list_workers[*].private_dns, local.list_workers[*].private_ip))
    list_master                      = join("\n", local.list_master[*].private_dns)
    list_node                        = join("\n", local.list_workers[*].private_dns)
    connection_strings_etcd          = join("\n", formatlist("%s ansible_host=%s", local.list_etcd[*].private_dns, local.list_etcd[*].private_ip))
    list_etcd                        = join("\n", ((length(local.list_etcd) > 0) ? (local.list_master[*].private_dns) : (local.list_master[*].private_dns)))
    elb_api_fqdn                     = "apiserver_loadbalancer_domain_name=${aws_route53_record.kube-api.fqdn}"
    workgroup = { for k, val in var.instance_groups : "${val.name}" => {
    for k, v in local.list_workers : k => v.private_dns if v.tags.Role == "${val.name}" } if val.name != "master" }
    workgroup_node_labels = { for k, v in var.instance_groups : "${v.name}" => v.labels }
    workgroup_nodes = { for k, v in var.instance_groups : v.name => {
      labels = [for label_key, label_value in v.labels : "\"${label_key}\":\"${label_value}\""]
      taints = [for taint_key, taint_value in v.taints : "\"${taint_key}=${taint_value}\""]
    } if length(v.labels) > 0 || length(v.taints) > 0 }
  })
}

resource "null_resource" "inventories" {
  provisioner "local-exec" {
    command = "echo '${local.template_file_init}' > ../${var.inventory_file}"
  }

  triggers = {
    template = local.template_file_init
  }
}

resource "aws_iam_role" "kube_control_plane" {
  name               = "${var.name}-k8s-cluster"
  assume_role_policy = templatefile("${path.module}/templates/ec2-assume-policy.tpl", {})
}

resource "aws_iam_role_policy" "kube_control_plane" {
  name = "${var.name}-master"
  role = aws_iam_role.kube_control_plane.id

  policy = templatefile("${path.module}/templates/master-policy.tpl", {})
}

resource "aws_iam_role" "kube-worker" {
  name               = "${var.name}-k8s-node"
  assume_role_policy = templatefile("${path.module}/templates/ec2-assume-policy.tpl", {})
}

resource "aws_iam_role_policy" "kube-worker" {
  name = "${var.name}-master"
  role = aws_iam_role.kube-worker.id

  policy = templatefile("${path.module}/templates/worker-policy.tpl", {})
}

resource "aws_iam_instance_profile" "kube_control_plane" {
  name = "kube_${var.name}_master_profile"
  role = aws_iam_role.kube_control_plane.name
}

resource "aws_iam_instance_profile" "kube-worker" {
  name = "kube_${var.name}_node_profile"
  role = aws_iam_role.kube-worker.name
}

resource "aws_route53_record" "kube-api" {
  zone_id = var.route53_hosted_zone_id
  name    = var.kube_api_record_name
  type    = var.kube_api_record_type

  alias {
    name                   = module.aws-elb.aws_elb_api_dns_name
    zone_id                = module.aws-elb.aws_elb_api_zone_id
    evaluate_target_health = var.kube_api_target_health_evaluation
  }
}
