variable "name" {
  description = "Tiền tố đặt tên cho tài nguyên"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block của VPC"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr phải là CIDR hợp lệ, ví dụ 10.0.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "Danh sách CIDR cho Public Subnets"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) > 0
    error_message = "Cần ít nhất 1 Public Subnet."
  }
}

variable "private_subnet_cidrs" {
  description = "Danh sách CIDR cho Private Subnets"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) > 0
    error_message = "Cần ít nhất 1 Private Subnet."
  }
}

variable "azs" {
  description = "Danh sách Availability Zones để rải subnet"
  type        = list(string)
}
