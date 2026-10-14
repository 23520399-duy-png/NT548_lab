output "nat_gateway_id" {
  description = "ID của NAT Gateway"
  value       = aws_nat_gateway.this.id
}

output "nat_public_ip" {
  description = "Public IP (Elastic IP) của NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "eip_allocation_id" {
  description = "Allocation ID của Elastic IP"
  value       = aws_eip.nat.id
}
