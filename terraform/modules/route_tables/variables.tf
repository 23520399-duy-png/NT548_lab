variable "name" {
  description = "Tiền tố đặt tên cho tài nguyên"
  type        = string
}

variable "vpc_id" {
  description = "ID của VPC"
  type        = string
}

variable "internet_gateway_id" {
  description = "ID của Internet Gateway (cho Public Route Table)"
  type        = string
}

variable "nat_gateway_id" {
  description = "ID của NAT Gateway (cho Private Route Table)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Danh sách Public Subnet IDs cần gắn Public Route Table"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Danh sách Private Subnet IDs cần gắn Private Route Table"
  type        = list(string)
}
