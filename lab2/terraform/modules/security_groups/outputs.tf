output "public_ec2_sg_id" {
  description = "ID của Public EC2 Security Group"
  value       = aws_security_group.public_ec2.id
}

output "private_ec2_sg_id" {
  description = "ID của Private EC2 Security Group"
  value       = aws_security_group.private_ec2.id
}

output "public_ssh_cidr" {
  description = "CIDR được phép SSH vào Public EC2"
  value       = aws_vpc_security_group_ingress_rule.public_ssh.cidr_ipv4
}

output "private_ssh_source_sg" {
  description = "Security Group nguồn được phép SSH vào Private EC2"
  value       = aws_vpc_security_group_ingress_rule.private_ssh_from_public.referenced_security_group_id
}
