output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  value = module.vpc.internet_gateway_id
}

output "default_security_group_id" {
  value = module.vpc.default_security_group_id
}

output "flow_logs_bucket" {
  description = "S3 bucket chứa VPC Flow Logs"
  value       = var.enable_flow_logs ? module.flow_logs_bucket[0].bucket_name : null
}

output "flow_log_id" {
  description = "ID của VPC Flow Log"
  value       = module.vpc.flow_log_id
}

output "nat_gateway_id" {
  value = module.nat_gateway.nat_gateway_id
}

output "nat_public_ip" {
  value = module.nat_gateway.nat_public_ip
}

output "public_route_table_id" {
  value = module.route_tables.public_route_table_id
}

output "private_route_table_id" {
  value = module.route_tables.private_route_table_id
}

output "public_ec2_sg_id" {
  value = module.security_groups.public_ec2_sg_id
}

output "private_ec2_sg_id" {
  value = module.security_groups.private_ec2_sg_id
}

output "public_instance_id" {
  value = module.public_ec2.instance_id
}

output "public_instance_public_ip" {
  value = module.public_ec2.public_ip
}

output "private_instance_id" {
  value = module.private_ec2.instance_id
}

output "private_instance_private_ip" {
  value = module.private_ec2.private_ip
}

output "ssh_public_command" {
  description = "Lệnh SSH vào Public EC2"
  value       = "ssh -i ~/.ssh/labsuser.pem ec2-user@${module.public_ec2.public_ip}"
}

output "ssh_private_command" {
  description = "Lệnh SSH vào Private EC2 thông qua Public EC2 (bastion)"
  value       = "ssh -i ~/.ssh/labsuser.pem -o ProxyCommand=\"ssh -i ~/.ssh/labsuser.pem -W %h:%p ec2-user@${module.public_ec2.public_ip}\" ec2-user@${module.private_ec2.private_ip}"
}
