# kodjin-mini

A set of Terraform manifests for an example of provisioning a `kodjin-mini` instance based on `Kodjin` ami-image 
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
terraform plan -out kodjin.tfplan
terraform apply kodjin.tfplan
```

4. Now you can request API Kodjin.

> Note: The default setup will be provided one AWS instance with public access to `Kodjin` API. 
> In the `variables.tf` file you can change the behavior and create an instance with private network support 
> via `instance_with_private_network` variable.
