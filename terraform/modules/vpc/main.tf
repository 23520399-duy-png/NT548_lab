###############################################################################
# Module: vpc
# Tạo VPC, Public/Private Subnets, Internet Gateway và Default Security Group
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
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
# Terraform "nhận quản lý" SG mặc định và siết lại theo best practice (CIS AWS 5.4):
#  - Chỉ cho phép các tài nguyên cùng SG nói chuyện với nhau
#  - Không mở bất kỳ port nào ra Internet
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress {
    description = "Allow all traffic from members of this default SG"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-default-sg"
  }
}
