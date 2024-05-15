# Kodjin Mini

A set of Terraform manifests for an example of provisioning a `kodjin-mini` instance based on `Kodjin` AMI 
from AWS Marketplace.

### Quick start guide

1. Create `.env` file with AWS credentials:
```shell
export AWS_REGION=<aws region>
export AWS_ACCESS_KEY_ID=<aws acces key id>
export AWS_SECRET_ACCESS_KEY=<aws SECRET ACCESS KEY>
export TF_VAR_AWS_REGION="${AWS_REGION}"
export TF_VAR_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export TF_VAR_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
```

2. Run the command to define environment variables:
```shell
set -a; source .env; set +a
```

3. Run the following Terraform commands while in the directory with a set of manifests:
```shell
terraform init -reconfigure
terraform plan -out kodjin-mini.tfplan
terraform apply kodjin-mini.tfplan
```

4. Now you can request Kodjin API.

> Note: The default setup will be provided one AWS instance with public access to `Kodjin` API. 
> In the `variables.tf` file you can change the behavior and create an instance with private network support 
> via `instance_with_private_network` variable.

### Configuration Kodjin Mini

#### Extend disk space size

By default this configuration example provide one disk for project with `200GB` size. 
But you can extend size through variable `instance_data_disk_size`.
```terraform
variable "instance_data_disk_size" {
  default     = 200
  description = "Specific instance data disk size for project"
  type        = number
}
```

After change value run `plan` and `apply` Terraform commands:
```shell
terraform plan -out kodjin-mini.tfplan
terraform apply kodjin-mini.tfplan
```

This will only change the disk size of the AWS instance, 
but in addition you need to change the size of each databases used within the project. 
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
- postgres.yaml
```yaml
volume:
  size: 2Gi
  storageClass: local-path
```
- redis.yaml
```yaml
master:
  persistence:
    storageClass: local-path
    size: 2Gi
```

Defining the environment name:
```shell
git branch
```

Apply change:
```shell
../scripts/project-setup.sh
```

#### Setup Kodjin Mini for private network

By default this configuration example provide only public network and promote public `Kodjin` API. 
But you can change this trough variable `instance_with_private_network`.
```terraform
variable "instance_with_private_network" {
  default     = false
  description = "Enable|Disable private network"
  type        = bool
}
```

After change value run `plan` and `apply` Terraform commands:
```shell
terraform plan -out kodjin-mini.tfplan
terraform apply kodjin-mini.tfplan
```

If you enable support for a private network, then two networks will be created for the AWS instance, 
one will be as before a public network with access to the instance via the SSH.
Second a private network with access via the SSH and ingress ports for the `Kodjin` API.
You can also change the default ingress ports for the `Kodjin` API,
if they are already used by other applications in your private network.
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
  description = "Specific instance ingress ports for project"
  type = list(object({
    host_port = number
  }))
}
```

### Note

- Terraform manifests will by default create a private SSH key in the user's home directory.
```terraform
output "ssh_access" {
  value = "ssh -i ${local_sensitive_file.local_file_bastion.filename} ${local.ssh_user}@${aws_eip.public_eip.public_dns}"
}
```

- This set of Terraform manifests is presented as an example of provisioning
  and installing `Kodjin` using the `Kodjin` AMI. 
  You can improve or change Terraform manifests at your discretion. 
  Basic requirements after provisioning the AWS instance, you must run the following set of commands 
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
