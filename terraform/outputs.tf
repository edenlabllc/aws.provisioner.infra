output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = !var.iaas_delivery ? module.eks[0].cluster_endpoint : ""
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = !var.iaas_delivery ? module.eks[0].cluster_security_group_id : ""
}

output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = !var.iaas_delivery ? module.eks[0].kubeconfig : ""
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = !var.iaas_delivery ? module.eks[0].config_map_aws_auth : []
  sensitive   = true
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "db_instance_endpoint" {
  description = "The connection endpoint"
  value       = var.db_enabled ? module.db[0].db_instance_endpoint : ""
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = var.db_enabled ? module.db[0].db_instance_status : ""
}

output "db_instance_name" {
  description = "The database name"
  value       = var.db_enabled ? module.db[0].db_instance_name : ""
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = var.db_enabled ? module.db[0].db_instance_username : ""
  sensitive   = true
}

output "db_instance_password" {
  description = "The database password (this password may be old, because Terraform doesn't track it after initial creation)"
  value       = var.db_enabled ? module.db[0].db_instance_password : ""
  sensitive   = true
}

output "db_instance_port" {
  description = "The database port"
  value       = var.db_enabled ? module.db[0].db_instance_port : ""
}

output "rmk_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks[0].cluster_id
}

output "rmk_hosted_zone_name" {
  description = "domain name for created hosted zone"
  value       = aws_route53_zone.hosted_zone.name
}

output "rmk_hosted_zone_id" {
  description = "hosted zone id"
  value       = aws_route53_zone.hosted_zone.zone_id
}

output "rmk_hosted_zone_ns_record" {
  description = "ns for created hosted zone"
  value       = aws_route53_zone.hosted_zone.name_servers[0]
}

output "rmk_lb_controller_iam_role_arn" {
  description = "IAM Role ARN for load balancer controller"
  value       = var.aws_lb_controller_role_enabled ? aws_iam_role.load-balancer-controller[0].arn : ""
}

output "rmk_lb_controller_sa_name" {
  description = "Service account name for load balancer controller"
  value       = var.aws_lb_controller_role_enabled ? split(":", var.aws_lb_controller_sa_name)[1] : ""
}

output "rmk_cluster_autoscaler_iam_role_arn" {
  description = "IAM Role ARN for cluster autoscaler"
  value       = var.cluster_autoscaler_roles_enabled ? aws_iam_role.cluster-autoscaler[0].arn : ""
}

output "rmk_cluster_autoscaler_sa_name" {
  description = "Service account name for cluster autoscaler"
  value       = var.cluster_autoscaler_roles_enabled ? split(":", var.cluster_autoscaler_sa_name)[1] : ""
}

output "rmk_ebs_csi_iam_role_arn" {
  description = "IAM Role ARN for ebs csi driver"
  value       = var.ebs_csi_controller_roles_enabled ? aws_iam_role.ebs-csi[0].arn : ""
}

output "rmk_ebs_csi_sa_name" {
  description = "Service account name for ebs csi driver"
  value       = var.ebs_csi_controller_roles_enabled ? split(":", var.ebs_csi_controller_sa_name)[1] : ""
}

output "rmk_ebs_snapshot_provision_iam_role_arn" {
  description = "IAM Role ARN for EBS snapshot provision"
  value       = var.ebs_csi_controller_roles_enabled ? aws_iam_role.ebs-snapshot-provision[0].arn : ""
}

output "rmk_ebs_snapshot_provision_sa_name" {
  description = "Service account name for EBS snapshot provision"
  value       = var.ebs_csi_controller_roles_enabled ? split(":", var.ebs_snapshot_provision_sa_name)[1] : ""
}

output "rmk_external_dns_iam_role_arn" {
  description = "IAM Role ARN for external dns"
  value       = var.external_dns_role_enabled ? aws_iam_role.external-dns[0].arn : ""
}

output "rmk_external_dns_sa_name" {
  description = "Service account name for external dns"
  value       = var.external_dns_role_enabled ? split(":", var.external_dns_sa_name)[1] : ""
}

output "rmk_acm_cert_arn" {
  description = "ACM certificate arn"
  value       = module.acm[0].this_acm_certificate_arn
}

output "rmk_test_suites" {
  description = "Whether test suites in cluster state enabled"
  value       = var.test_suites
}

output "bastion_private_key_path" {
  description = "Path to private key for connecting to EC2 bastion instance via SSH"
  value       = var.bastion_enabled ? abspath(local_file.local_file_bastion[0].filename) : ""
}

output "bastion_ssh_private_key_name" {
  description = "Private key name for connecting to EC2 bastion instance via SSH"
  value       = var.bastion_enabled ? local.ssh_private_key_name_bastion : ""
}

output "bastion_user" {
  description = "User of EC2 bastion instance"
  value       = var.bastion_enabled ? local.ssh_user_bastion : ""
}

output "bastion_public_host" {
  description = "Public DNS Name of EC2 bastion instance"
  value       = var.bastion_enabled ? aws_instance.instance_bastion[0].public_dns : ""
}
