output "kodjin_API_URL" {
  value = "https://${aws_eip.public_eip.public_dns}${var.instance_ingress_ports[1].host_port != 443 ? format(":%s", var.instance_ingress_ports[1].host_port) : ""}/fhir"
}

output "private_dns" {
  value = var.instance_with_private_network ? aws_network_interface.subnet_private_eni[0].private_dns_name : null
}

output "private_ip" {
  value = var.instance_with_private_network ? aws_network_interface.subnet_private_eni[0].private_ip : null
}

output "public_dns" {
  value = aws_eip.public_eip.public_dns
}

output "public_ip" {
  value = aws_eip.public_eip.public_ip
}

output "ssh_access" {
  value = "ssh -i ${local_sensitive_file.local_file_bastion.filename} ${local.ssh_user}@${aws_eip.public_eip.public_dns}"
}
