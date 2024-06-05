# Kodjin Mini

A set of [Terraform](https://www.terraform.io/) manifests with examples 
of provisioning a `Kodjin Mini` instance based on [Kodjin](https://kodjin.com) AMI 
from AWS Marketplace.

### Quick start guide

1. Create `.env` file with AWS credentials:

```shell
export AWS_REGION=<aws_region>
export AWS_ACCESS_KEY_ID=<aws_access_key_id>
export AWS_SECRET_ACCESS_KEY=<aws_secret_access_key>
export TF_VAR_AMI_IMAGE_OWNER=<aws_ami_image_owner_account_id>
export TF_VAR_AWS_REGION="${AWS_REGION}"
export TF_VAR_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export TF_VAR_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
```

> `TF_VAR_*` variables are used by Terraform.

2. Run the following commands to initialize environment variables:

```shell
set -a; source .env; set +a
```

3. Run the following Terraform commands while in the directory with a set of manifests:

```shell
terraform init -reconfigure
terraform plan -out kodjin-mini.tfplan
terraform apply kodjin-mini.tfplan
```

4. Now you can request the `Kodjin` API.

> Note: The default setup will provide one AWS instance with public access to the `Kodjin` API. 
> In the `variables.tf` file you can change the default behavior and create an instance with private network support 
> via the `instance_with_private_network` variable.

### Configuration of Kodjin Mini

#### Extension of data disk size

By default, this configuration example provide one disk of a `200GB` size for the project. 
However, you can extend the default size through the `instance_data_disk_size` variable.

```terraform
variable "instance_data_disk_size" {
  default     = 200
  description = "Instance data disk size for project"
  type        = number
}
```

After changing the values run `plan` and `apply` Terraform commands:

```shell
terraform plan -out kodjin-mini.tfplan
terraform apply kodjin-mini.tfplan
```

This will only change the disk size of the AWS instance, 
but in addition you need to change the size of each database used within the project. 
To do this, connect via SSH to the instance.
You will automatically be taken to the project directory. 
Find the directory according to your environment name: `etc/deps/<develop|staging|production>/values/k3d/values`.
For the following files, change the size of the `PVC` in proportion to the increase in disk space:

- elastic.yaml

```yaml
esNodeSet:
  - volumeClaimTemplates:
      storage: 20Gi
      storageClassName: local-path
```

- fhir-postgres.yaml

```yaml
volume:
  size: 20Gi
  storageClass: local-path
```

- kafka.yaml

```yaml
kafka:
  storage:
    class: local-path
    size: 20Gi
```

- mongodb.yaml

```yaml
persistence:
  storageClass: local-path
  size: 20Gi
```

Get the current environment name:

```shell
git branch
```

Apply the changes:

```shell
../scripts/project-setup.sh
```

#### Setup Kodjin Mini for private networks

By default, this configuration example provides only public networks and promotes the `Kodjin` API. 
However, you can change this via the `instance_with_private_network` variable:

```terraform
variable "instance_with_private_network" {
  default     = false
  description = "Enable|Disable private network"
  type        = bool
}
```

After changing the values run `plan` and `apply` Terraform commands:

```shell
terraform plan -out kodjin-mini.tfplan
terraform apply kodjin-mini.tfplan
```

If you enable support for a private network, then two networks will be created for the AWS instance, 
The first one will be the same as before: a public network with access to the instance via the SSH.
The second one will be a private network with access via the SSH and ingress ports for the `Kodjin` API.
You can also change the default ingress ports for the `Kodjin` API,
if they are already used by other applications in your private networks.

```terraform
variable "instance_ingress_ports" {
  default = [
    {
      host_port = 80
    },
    {
      host_port = 443
    }
  ]
  description = "Instance ingress ports for project"
  type = list(object({
    host_port = number
  }))
}
```

### Important notes

- Terraform manifests will by default create a private SSH key in the user's home directory.

```terraform
output "ssh_access" {
  value = "ssh -i ${local_sensitive_file.local_file_bastion.filename} ${local.ssh_user}@${aws_eip.public_eip.public_dns}"
}
```

- This set of Terraform manifests is presented as an example of provisioning
  and installing `Kodjin` using the `Kodjin` AMI. 
  You can improve or change Terraform manifests to your needs. 
  The basic requirements after provisioning the AWS instance are that you must run the following set of commands 
  to complete the `Kodjin` installation.

```terraform
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
```
