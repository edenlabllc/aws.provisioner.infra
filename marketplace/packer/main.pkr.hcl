packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp      = regex_replace(timestamp(), "[- TZ:]", "")
  version        = "${var.project_version}-linux-amd64"
  ami_image_name = "${var.project_organization}-${var.project_name}-${local.version}-${local.timestamp}"
  project_env_variables = merge(var.project_env_variables, {
    PROJECT_NAME         = var.project_name,
    PROJECT_ENVIRONMENT  = var.project_environment,
    PROJECT_ORGANIZATION = var.project_organization
  })
}

data "amazon-ami" "base_image_filter" {
  filters = {
    name                = var.aws_base_image_filter
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }

  most_recent = true
  owners      = ["amazon"]
}

source "amazon-ebs" "source_base_image" {
  ami_name        = local.ami_image_name
  source_ami      = data.amazon-ami.base_image_filter.id
  instance_type   = var.aws_instance_type
  region          = var.aws_region
  ssh_username    = var.aws_instance_ssh_username
  skip_create_ami = var.aws_skip_create_ami
  ena_support     = true

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = var.aws_instance_launch_block_device.device_name
    volume_type           = "gp3"
    volume_size           = var.aws_instance_launch_block_device.volume_size
  }

  run_tags = {
    AMIName            = local.ami_image_name
    Name               = "${var.project_name}-light"
    ProjectName        = var.project_name
    ProjectEnvironment = var.project_environment
    ProjectVersion     = replace(local.version, "-linux-amd64", "")
  }
}

build {
  sources = ["source.amazon-ebs.source_base_image"]

  provisioner "shell" {
    environment_vars = [
      "PROJECT_NAME=${var.project_name}"
    ]
    expect_disconnect = true
    script            = "${path.root}/scripts/system-setup.sh"
  }

  provisioner "file" {
    sources     = [for file in fileset(".", "scripts/*.sh") : "${path.root}/${file}"]
    destination = "/home/${build.User}/scripts/"
  }

  provisioner "file" {
    content     = templatefile("templates/.env.tpl", { project_env_variables = local.project_env_variables, project_name = var.project_name, project_user = var.aws_instance_ssh_username })
    destination = "/home/${build.User}/${var.project_name}/.env.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "PROJECT_NAME=${var.project_name}"
    ]
    expect_disconnect = true
    script            = "${path.root}/scripts/system-add-environment.sh"
  }

  provisioner "file" {
    sources = [
      "${path.cwd}/etc",
      "${path.cwd}/docs"
    ]
    destination = "/home/${build.User}/${var.project_name}/"
  }

  provisioner "file" {
    sources = [
      "${path.cwd}/.gitignore",
      "${path.cwd}/helmfile.yaml.gotmpl",
      "${path.cwd}/project.yaml",
      "${path.cwd}/README.md",
      "${path.cwd}/version.yaml"
    ]
    destination = "/home/${build.User}/${var.project_name}/"
  }

  provisioner "shell" {
    environment_vars = [
      "PROJECT_NAME=${var.project_name}"
    ]
    expect_disconnect = true
    script            = "${path.root}/scripts/project-secrets-clean.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "AWS_REGION=${var.aws_region}",
      "AWS_ACCESS_KEY_ID=${var.aws_access_key_id}",
      "AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key}",
      "PROJECT_NAME=${var.project_name}",
      "PROJECT_ENVIRONMENT=${var.project_environment}",
      "PROJECT_ORGANIZATION=${var.project_organization}",
      "RMK_ROOT_DOMAIN=${var.rmk_root_domain}",
      "RMK_VERSION=${var.rmk_version}"
    ]
    expect_disconnect = true
    script            = "${path.root}/scripts/project-prepare.sh"
  }
}
