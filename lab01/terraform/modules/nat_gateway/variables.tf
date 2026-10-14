variable "name" {
  description = "Tiền tố đặt tên cho tài nguyên"
  type        = string
}

variable "public_subnet_id" {
  description = "ID của Public Subnet chứa NAT Gateway"
  type        = string
}
