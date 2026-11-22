###############################################################################
# Root module - NT548 Lab 02 (Câu 1)
# Ghép các module: flow_logs_bucket -> vpc -> nat_gateway -> route_tables
#                  -> security_groups -> ec2
# Hạ tầng giống Lab 01, được siết thêm theo khuyến nghị của Checkov.
###############################################################################

# Chỉ định rõ AZ a/b của region (Checkov CKV_AWS_394: không để danh sách AZ
# tự nở ra khi AWS thêm AZ mới -> plan luôn ổn định).
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-name"
    values = ["${var.aws_region}a", "${var.aws_region}b"]
  }
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

data "aws_caller_identity" "current" {}

locals {
  name   = var.project_name
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023.id
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)

  # Bucket nhận VPC Flow Logs. Mặc định: <project>-flowlogs-<account>-<region>,
  # được tạo sẵn bằng scripts/bootstrap-backend.sh (AWS CLI).
  flow_logs_bucket_name = (
    var.create_flow_logs_bucket ? module.flow_logs_bucket[0].bucket_name :
    var.flow_logs_bucket_name != "" ? var.flow_logs_bucket_name :
    "${local.name}-flowlogs-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )
  flow_logs_bucket_arn = "arn:aws:s3:::${local.flow_logs_bucket_name}"
}

# 0. (Tuỳ chọn) S3 bucket chứa VPC Flow Logs do Terraform tạo.
# Mặc định TẮT: AWS Academy chặn s3:GetBucketObjectLockConfiguration bằng
# Service Control Policy, mà AWS provider luôn gọi API này khi đọc aws_s3_bucket
# -> apply lỗi AccessDenied. Trên tài khoản AWS thường đặt
# create_flow_logs_bucket = true để Terraform tự quản lý bucket.
module "flow_logs_bucket" {
  source = "./modules/flow_logs_bucket"
  count  = var.enable_flow_logs && var.create_flow_logs_bucket ? 1 : 0

  name           = local.name
  retention_days = var.flow_logs_retention_days
}

# 1. VPC + Subnets + IGW + Default SG + Flow Logs
module "vpc" {
  source = "./modules/vpc"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = local.azs
  enable_flow_logs     = var.enable_flow_logs
  flow_logs_bucket_arn = var.enable_flow_logs ? local.flow_logs_bucket_arn : null
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

  name                 = "${local.name}-public-ec2"
  role                 = "public"
  ami_id               = local.ami_id
  instance_type        = var.instance_type
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.security_groups.public_ec2_sg_id]
  key_name             = var.key_name
  iam_instance_profile = var.iam_instance_profile
  associate_public_ip  = true

  depends_on = [module.route_tables]
}

# 5b. Private EC2 - chỉ truy cập được từ Public EC2
module "private_ec2" {
  source = "./modules/ec2"

  name                 = "${local.name}-private-ec2"
  role                 = "private"
  ami_id               = local.ami_id
  instance_type        = var.instance_type
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.private_ec2_sg_id]
  key_name             = var.key_name
  iam_instance_profile = var.iam_instance_profile
  associate_public_ip  = false

  # Đợi route qua NAT sẵn sàng để instance private có Internet ngay khi boot
  depends_on = [module.route_tables]
}
