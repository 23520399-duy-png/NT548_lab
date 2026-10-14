###############################################################################
# Root module - NT548 Lab 01
# Ghép các module: vpc -> nat_gateway -> route_tables -> security_groups -> ec2
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# Amazon Linux 2023 mới nhất (x86_64)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name   = var.project_name
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023.id
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
}

# 1. VPC + Subnets + IGW + Default SG
module "vpc" {
  source = "./modules/vpc"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = local.azs
}

# 2. NAT Gateway (đặt ở Public Subnet đầu tiên).
#    depends_on: NAT cần IGW đã gắn vào VPC trước khi tạo.
module "nat_gateway" {
  source = "./modules/nat_gateway"

  name             = local.name
  public_subnet_id = module.vpc.public_subnet_ids[0]

  depends_on = [module.vpc]
}

# 3. Route Tables Public/Private
module "route_tables" {
  source = "./modules/route_tables"

  name                = local.name
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.vpc.internet_gateway_id
  nat_gateway_id      = module.nat_gateway.nat_gateway_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
}

# 4. Security Groups cho EC2
module "security_groups" {
  source = "./modules/security_groups"

  name             = local.name
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# 5a. Public EC2 (bastion) - truy cập được từ Internet (chỉ từ IP cho phép)
module "public_ec2" {
  source = "./modules/ec2"

  name                = "${local.name}-public-ec2"
  role                = "public"
  ami_id              = local.ami_id
  instance_type       = var.instance_type
  subnet_id           = module.vpc.public_subnet_ids[0]
  security_group_ids  = [module.security_groups.public_ec2_sg_id]
  key_name            = var.key_name
  associate_public_ip = true

  depends_on = [module.route_tables]
}

# 5b. Private EC2 - chỉ truy cập được từ Public EC2
module "private_ec2" {
  source = "./modules/ec2"

  name                = "${local.name}-private-ec2"
  role                = "private"
  ami_id              = local.ami_id
  instance_type       = var.instance_type
  subnet_id           = module.vpc.private_subnet_ids[0]
  security_group_ids  = [module.security_groups.private_ec2_sg_id]
  key_name            = var.key_name
  associate_public_ip = false

  # Đợi route qua NAT sẵn sàng để instance private có Internet ngay khi boot
  depends_on = [module.route_tables]
}
