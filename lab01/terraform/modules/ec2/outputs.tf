output "instance_id" {
  description = "ID của EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP của instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP của instance (rỗng nếu là private instance)"
  value       = aws_instance.this.public_ip
}

output "subnet_id" {
  description = "Subnet chứa instance"
  value       = aws_instance.this.subnet_id
}
