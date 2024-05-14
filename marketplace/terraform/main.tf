provider "aws" {
  default_tags {
    tags = {
      AMIName             = "${var.project_organization}-${var.project_name}-${var.project_version}-linux-amd64"
      Name                = "${var.project_name}-mini"
      ProjectName         = var.project_name
      ProjectEnvironment  = var.project_environment
      ProjectVersion      = var.project_version
      ProjectOrganization = var.project_organization
    }
  }

  region = var.AWS_REGION
}

provider "local" {
}

locals {
  ami_image_prefix            = "${var.project_organization}-${var.project_name}-${var.project_version}-linux-amd64-*"
  availability_zone           = "${var.AWS_REGION}a"
  ssh_private_key_name        = "${var.project_name}-private-key.pem"
  ssh_private_key_permissions = "0400"
  ssh_user                    = var.ssh_username
}

data "aws_ami" "filter" {
  filter {
    name   = "name"
    values = [local.ami_image_prefix]
  }

  most_recent = true
  owners      = [var.ami_image_owner]
}

resource "tls_private_key" "ed25519" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "local_file_bastion" {
  content         = tls_private_key.ed25519.private_key_openssh
  file_permission = local.ssh_private_key_permissions
  filename        = pathexpand("~/.ssh/${local.ssh_private_key_name}")
}

resource "aws_key_pair" "deployer" {
  key_name_prefix = "${var.project_name}-private-key-"
  public_key      = tls_private_key.ed25519.public_key_openssh
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet_public" {
  availability_zone       = local.availability_zone
  cidr_block              = var.cidr_public_subnet
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet_private" {
  count = var.instance_with_private_network ? 1 : 0

  availability_zone       = local.availability_zone
  cidr_block              = var.cidr_private_subnet
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.vpc.id
}

resource "aws_route_table" "rtb_public" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "rta_subnet_public" {
  route_table_id = aws_route_table.rtb_public.id
  subnet_id      = aws_subnet.subnet_public.id
}

resource "aws_security_group" "sg_ingress_public_ports" {
  count = var.instance_with_private_network ? 1 : 0

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

  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "sg_ingress_ports" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.instance_ingress_ports[0].host_port
    to_port     = var.instance_ingress_ports[0].host_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.instance_ingress_ports[1].host_port
    to_port     = var.instance_ingress_ports[1].host_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.vpc.id
}

resource "aws_network_interface" "subnet_public_eni" {
  security_groups = [var.instance_with_private_network ? aws_security_group.sg_ingress_public_ports[0].id : aws_security_group.sg_ingress_ports.id]
  subnet_id       = aws_subnet.subnet_public.id
}

resource "aws_network_interface" "subnet_private_eni" {
  count = var.instance_with_private_network ? 1 : 0

  security_groups = [aws_security_group.sg_ingress_ports.id]
  subnet_id       = aws_subnet.subnet_private[0].id
}

resource "aws_eip" "public_eip" {
  network_interface = aws_network_interface.subnet_public_eni.id
  vpc               = true
}

resource "aws_instance" "kodjin" {
  ami               = data.aws_ami.filter.id
  availability_zone = local.availability_zone
  instance_type     = var.instance_type
  key_name          = aws_key_pair.deployer.key_name
  monitoring        = false

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.subnet_public_eni.id
    delete_on_termination = false
  }

  dynamic "network_interface" {
    for_each = var.instance_with_private_network ? [1] : []
    content {
      device_index          = 1
      network_interface_id  = aws_network_interface.subnet_private_eni[0].id
      delete_on_termination = false
    }
  }

  root_block_device {
    delete_on_termination = false
    encrypted             = true
    volume_size           = var.instance_data_disk_size
    tags                  = {
      AMIName             = "${var.project_organization}-${var.project_name}-${var.project_version}-linux-amd64"
      Name                = "${var.project_name}-light"
      ProjectName         = var.project_name
      ProjectEnvironment  = var.project_environment
      ProjectVersion      = var.project_version
      ProjectOrganization = var.project_organization
    }
  }
}

resource "null_resource" "extend_disk_size" {
  connection {
    host        = aws_eip.public_eip.public_dns
    private_key = file(local_sensitive_file.local_file_bastion.filename)
    timeout     = "1m"
    type        = "ssh"
    user        = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = ["sudo -S growpart /dev/nvme0n1 1 && sudo -S xfs_growfs -d / || exit 0"]
  }

  triggers = {
    root_block_device_volume_size = aws_instance.kodjin.root_block_device[0].volume_size
  }
}

resource "null_resource" "project_setup" {
  connection {
    host        = aws_eip.public_eip.public_dns
    private_key = file(local_sensitive_file.local_file_bastion.filename)
    timeout     = "1m"
    type        = "ssh"
    user        = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      "source /etc/profile",
      "cd /home/${local.ssh_user}/${var.project_name}",
      "export AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}",
      "export AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}",
      "export AWS_REGION=${var.AWS_REGION}",
      "export RMK_ROOT_DOMAIN=${var.instance_with_private_network ? aws_network_interface.subnet_private_eni[0].private_dns_name : aws_eip.public_eip.public_dns}",
      "export HOST_PORT_0=${var.instance_ingress_ports[0].host_port}",
      "export HOST_PORT_1=${var.instance_ingress_ports[1].host_port}",
      "../scripts/project-setup.sh"
    ]
  }

  depends_on = [null_resource.extend_disk_size]

  triggers = {
    ingres_port_1 = var.instance_ingress_ports[0].host_port
    ingres_port_2 = var.instance_ingress_ports[1].host_port
  }
}
