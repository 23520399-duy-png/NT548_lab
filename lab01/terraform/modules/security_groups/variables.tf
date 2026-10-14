variable "name" {
  description = "Tiền tố đặt tên cho tài nguyên"
  type        = string
}

variable "vpc_id" {
  description = "ID của VPC"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "IP được phép SSH vào Public EC2, dạng x.x.x.x/32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr)) && var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "allowed_ssh_cidr phải là CIDR hợp lệ và KHÔNG được là 0.0.0.0/0 (ví dụ: 1.2.3.4/32)."
  }
}

variable "allow_icmp_from_public" {
  description = "Cho phép ping (ICMP) từ Public EC2 tới Private EC2 để kiểm thử"
  type        = bool
  default     = true
}
