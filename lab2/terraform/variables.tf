variable "aws_region" {
  description = "AWS Region (AWS Academy Learner Lab: us-east-1 hoặc us-west-2)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Tiền tố đặt tên cho mọi tài nguyên"
  type        = string
  default     = "nt548-lab02"
}

variable "vpc_cidr" {
  description = "CIDR của VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR cho Public Subnets"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR cho Private Subnets"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "allowed_ssh_cidr" {
  description = "IP được phép SSH vào Public EC2, dạng x.x.x.x/32 (lấy bằng: curl -s https://checkip.amazonaws.com)"
  type        = string
}

variable "instance_type" {
  description = "Loại EC2 instance"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Tên EC2 Key Pair. AWS Academy có sẵn key 'vockey' (tải labsuser.pem ở AWS Details)"
  type        = string
  default     = "vockey"
}

variable "ami_id" {
  description = "AMI ID tuỳ chọn. Để trống -> tự lấy Amazon Linux 2023 mới nhất"
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "Instance profile gắn vào EC2. AWS Academy không cho tạo IAM Role nên dùng 'LabInstanceProfile' có sẵn"
  type        = string
  default     = "LabInstanceProfile"
}

variable "enable_flow_logs" {
  description = "Bật VPC Flow Logs (ghi ra S3) – yêu cầu của Checkov CKV2_AWS_11"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Số ngày giữ Flow Logs trong S3 trước khi tự xoá"
  type        = number
  default     = 7
}
