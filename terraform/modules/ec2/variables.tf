variable "name" {
  description = "Tên (tag Name) của instance"
  type        = string
}

variable "role" {
  description = "Vai trò của instance (public/private) - dùng làm tag"
  type        = string
}

variable "ami_id" {
  description = "AMI ID"
  type        = string
}

variable "instance_type" {
  description = "Loại instance (AWS Academy cho phép t2/t3 nano -> medium)"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet đặt instance"
  type        = string
}

variable "security_group_ids" {
  description = "Danh sách Security Group gắn vào instance"
  type        = list(string)
}

variable "key_name" {
  description = "Tên EC2 Key Pair (AWS Academy có sẵn 'vockey')"
  type        = string
}

variable "associate_public_ip" {
  description = "Có gán Public IP hay không"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Script user data (tuỳ chọn)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Dung lượng root volume (GiB)"
  type        = number
  default     = 8
}
