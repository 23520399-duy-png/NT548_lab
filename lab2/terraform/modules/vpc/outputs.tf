output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR của VPC"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID của Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "Danh sách ID Public Subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Danh sách ID Private Subnets"
  value       = aws_subnet.private[*].id
}

output "default_security_group_id" {
  description = "ID của Default Security Group"
  value       = aws_default_security_group.this.id
}

output "flow_log_id" {
  description = "ID của VPC Flow Log (null nếu không bật)"
  value       = try(aws_flow_log.this[0].id, null)
}

output "flow_log_traffic_type" {
  description = "Loại traffic được ghi Flow Log (null nếu không bật)"
  value       = try(aws_flow_log.this[0].traffic_type, null)
}
