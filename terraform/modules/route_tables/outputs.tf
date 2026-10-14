output "public_route_table_id" {
  description = "ID của Public Route Table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID của Private Route Table"
  value       = aws_route_table.private.id
}

output "public_default_route_target" {
  description = "Target của route 0.0.0.0/0 trong Public RT (IGW)"
  value       = aws_route.public_internet.gateway_id
}

output "private_default_route_target" {
  description = "Target của route 0.0.0.0/0 trong Private RT (NAT GW)"
  value       = aws_route.private_nat.nat_gateway_id
}
