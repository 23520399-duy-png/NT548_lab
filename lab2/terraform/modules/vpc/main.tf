###############################################################################
# Module: vpc
# Tạo VPC, Public/Private Subnets, Internet Gateway, Default Security Group
# và VPC Flow Logs (ghi ra S3 bucket do module flow_logs_bucket tạo).
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

# VPC Flow Logs: ghi toàn bộ traffic (ACCEPT + REJECT) ra S3 – CKV2_AWS_11
resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.flow_logs_bucket_arn

  tags = {
    Name = "${var.name}-vpc-flow-log"
  }
}

# Internet Gateway gắn vào VPC -> Public Subnet đi Internet qua IGW (route ở module route_tables)
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# Public Subnets: instance được cấp Public IP tự động
resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:Public Subnet chứa bastion và NAT Gateway, cần tự gán Public IP theo thiết kế

  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-subnet-${count.index + 1}"
    Tier = "public"
  }
}

# Private Subnets: KHÔNG cấp Public IP, đi Internet qua NAT Gateway
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-private-subnet-${count.index + 1}"
    Tier = "private"
  }
}

# Default Security Group của VPC:
# Terraform "nhận quản lý" SG mặc định và XOÁ HẾT rule (CIS AWS 5.4 /
# Checkov CKV2_AWS_12): tài nguyên nào lỡ gắn vào SG default sẽ không nhận và
# không gửi được traffic -> buộc phải dùng Security Group riêng có chủ đích.
# (Lab 01 cho phép traffic nội bộ "self"; Lab 02 siết chặt hơn.)
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # Không khai báo ingress/egress => Terraform xoá toàn bộ rule mặc định

  tags = {
    Name = "${var.name}-default-sg"
  }
}
