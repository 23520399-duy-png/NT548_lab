###############################################################################
# UNIT TESTS - chạy OFFLINE bằng mock provider (không tạo tài nguyên thật,
# không tốn tiền, không cần credentials AWS).
#
#   cd terraform
#   terraform init -backend=false
#   terraform test -test-directory=tests/unit
#
# Mỗi run block kiểm tra 1 dịch vụ (1 module) theo yêu cầu đề bài.
###############################################################################

mock_provider "aws" {
  # Mock provider sinh chuỗi ngẫu nhiên cho "arn" -> aws_flow_log báo ARN sai.
  # Gán ARN hợp lệ cho S3 bucket giả lập.
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-flowlogs-bucket"
    }
  }
}

# --------------------------------------------------------------------------- #
# TC-01: VPC + Subnets + Internet Gateway + Default Security Group
# --------------------------------------------------------------------------- #
run "tc01_vpc" {
  command = apply

  module {
    source = "./modules/vpc"
  }

  variables {
    name                 = "test"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_cidrs  = ["10.0.1.0/24"]
    private_subnet_cidrs = ["10.0.2.0/24"]
    azs                  = ["us-east-1a", "us-east-1b"]
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR không đúng"
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames && aws_vpc.this.enable_dns_support
    error_message = "VPC phải bật DNS support/hostnames"
  }

  assert {
    condition     = length(aws_subnet.public) == 1 && length(aws_subnet.private) == 1
    error_message = "Phải có 1 Public Subnet và 1 Private Subnet"
  }

  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == true
    error_message = "Public Subnet phải tự gán Public IP"
  }

  assert {
    condition     = aws_subnet.private[0].map_public_ip_on_launch == false
    error_message = "Private Subnet KHÔNG được tự gán Public IP"
  }

  assert {
    condition     = alltrue([for s in concat(aws_subnet.public, aws_subnet.private) : s.vpc_id == aws_vpc.this.id])
    error_message = "Các subnet phải nằm trong VPC vừa tạo"
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Mặc định module vpc không tạo Flow Log khi chưa bật"
  }

  assert {
    condition     = aws_internet_gateway.this.vpc_id == aws_vpc.this.id
    error_message = "Internet Gateway phải được gắn vào VPC"
  }

  assert {
    condition     = aws_default_security_group.this.vpc_id == aws_vpc.this.id
    error_message = "Default SG phải thuộc VPC"
  }

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "Default SG phải bị xoá hết rule (chặn toàn bộ traffic) – CKV2_AWS_12"
  }
}

# TC-01b: VPC CIDR sai định dạng phải bị từ chối
run "tc01b_vpc_invalid_cidr" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    name                 = "test"
    vpc_cidr             = "not-a-cidr"
    public_subnet_cidrs  = ["10.0.1.0/24"]
    private_subnet_cidrs = ["10.0.2.0/24"]
    azs                  = ["us-east-1a"]
  }

  expect_failures = [var.vpc_cidr]
}

# --------------------------------------------------------------------------- #
# TC-01c: S3 bucket chứa Flow Logs
# --------------------------------------------------------------------------- #
run "tc01c_flow_logs_bucket" {
  command = apply

  module {
    source = "./modules/flow_logs_bucket"
  }

  variables {
    name           = "test"
    retention_days = 7
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "Bucket log phải chặn hoàn toàn truy cập public"
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Bucket log phải bật versioning"
  }

  assert {
    condition     = one([for r in aws_s3_bucket_server_side_encryption_configuration.this.rule : r.apply_server_side_encryption_by_default[0].sse_algorithm]) == "AES256"
    error_message = "Bucket log phải mã hoá SSE"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].expiration[0].days == 7
    error_message = "Log phải tự xoá sau retention_days ngày"
  }
}

# TC-01d: retention_days không hợp lệ phải bị từ chối
run "tc01d_flow_logs_invalid_retention" {
  command = plan

  module {
    source = "./modules/flow_logs_bucket"
  }

  variables {
    name           = "test"
    retention_days = 0
  }

  expect_failures = [var.retention_days]
}

# --------------------------------------------------------------------------- #
# TC-02: NAT Gateway
# --------------------------------------------------------------------------- #
run "tc02_nat_gateway" {
  command = apply

  module {
    source = "./modules/nat_gateway"
  }

  variables {
    name             = "test"
    public_subnet_id = run.tc01_vpc.public_subnet_ids[0]
  }

  assert {
    condition     = aws_nat_gateway.this.subnet_id == var.public_subnet_id
    error_message = "NAT Gateway phải nằm trong Public Subnet"
  }

  assert {
    condition     = aws_nat_gateway.this.allocation_id == aws_eip.nat.id
    error_message = "NAT Gateway phải dùng Elastic IP vừa tạo"
  }

  assert {
    condition     = aws_nat_gateway.this.connectivity_type == "public" && aws_eip.nat.domain == "vpc"
    error_message = "NAT Gateway phải là loại public, EIP domain = vpc"
  }
}

# --------------------------------------------------------------------------- #
# TC-03: Route Tables
# --------------------------------------------------------------------------- #
run "tc03_route_tables" {
  command = apply

  module {
    source = "./modules/route_tables"
  }

  variables {
    name                = "test"
    vpc_id              = run.tc01_vpc.vpc_id
    internet_gateway_id = run.tc01_vpc.internet_gateway_id
    nat_gateway_id      = run.tc02_nat_gateway.nat_gateway_id
    public_subnet_ids   = run.tc01_vpc.public_subnet_ids
    private_subnet_ids  = run.tc01_vpc.private_subnet_ids
  }

  assert {
    condition = (
      aws_route.public_internet.destination_cidr_block == "0.0.0.0/0" &&
      aws_route.public_internet.gateway_id == var.internet_gateway_id
    )
    error_message = "Public RT phải có route 0.0.0.0/0 -> Internet Gateway"
  }

  assert {
    condition = (
      aws_route.private_nat.destination_cidr_block == "0.0.0.0/0" &&
      aws_route.private_nat.nat_gateway_id == var.nat_gateway_id
    )
    error_message = "Private RT phải có route 0.0.0.0/0 -> NAT Gateway"
  }

  assert {
    condition     = aws_route_table_association.public[0].subnet_id == var.public_subnet_ids[0]
    error_message = "Public Subnet phải được gắn vào Public RT"
  }

  assert {
    condition     = aws_route_table_association.private[0].subnet_id == var.private_subnet_ids[0]
    error_message = "Private Subnet phải được gắn vào Private RT"
  }

  assert {
    condition     = aws_route_table.public.tags["Name"] == "test-public-rt" && aws_route_table.private.tags["Name"] == "test-private-rt"
    error_message = "Public và Private phải dùng 2 Route Table riêng"
  }
}

# --------------------------------------------------------------------------- #
# TC-04: Security Groups
# --------------------------------------------------------------------------- #
run "tc04_security_groups" {
  command = apply

  module {
    source = "./modules/security_groups"
  }

  variables {
    name             = "test"
    vpc_id           = run.tc01_vpc.vpc_id
    allowed_ssh_cidr = "203.0.113.10/32"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.public_ssh.from_port == 22 &&
      aws_vpc_security_group_ingress_rule.public_ssh.to_port == 22 &&
      aws_vpc_security_group_ingress_rule.public_ssh.ip_protocol == "tcp"
    )
    error_message = "Public SG chỉ được mở port 22/TCP"
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.public_ssh.cidr_ipv4 == "203.0.113.10/32"
    error_message = "Public SG chỉ cho SSH từ IP được chỉ định"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.private_ssh_from_public.referenced_security_group_id == aws_security_group.public_ec2.id &&
      aws_vpc_security_group_ingress_rule.private_ssh_from_public.cidr_ipv4 == null
    )
    error_message = "Private SG chỉ cho SSH từ Public EC2 SG, không từ CIDR nào"
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.private_ssh_from_public.from_port == 22
    error_message = "Private SG phải mở port 22 cho bastion"
  }
}

# TC-04b: Không cho phép mở SSH ra toàn Internet
run "tc04b_reject_open_ssh" {
  command = plan

  module {
    source = "./modules/security_groups"
  }

  variables {
    name             = "test"
    vpc_id           = "vpc-12345678"
    allowed_ssh_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.allowed_ssh_cidr]
}

# --------------------------------------------------------------------------- #
# TC-05: EC2 Public & Private
# --------------------------------------------------------------------------- #
run "tc05a_public_ec2" {
  command = apply

  module {
    source = "./modules/ec2"
  }

  variables {
    name                 = "test-public"
    role                 = "public"
    ami_id               = "ami-0123456789abcdef0"
    subnet_id            = run.tc01_vpc.public_subnet_ids[0]
    security_group_ids   = [run.tc04_security_groups.public_ec2_sg_id]
    key_name             = "vockey"
    iam_instance_profile = "LabInstanceProfile"
    associate_public_ip  = true
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == true
    error_message = "Public EC2 phải có Public IP"
  }

  assert {
    condition     = aws_instance.this.subnet_id == var.subnet_id
    error_message = "Public EC2 phải nằm trong Public Subnet"
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "EC2 phải bắt buộc IMDSv2"
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true
    error_message = "Root volume phải được mã hoá"
  }

  assert {
    condition     = aws_instance.this.monitoring == true && aws_instance.this.ebs_optimized == true
    error_message = "EC2 phải bật detailed monitoring và EBS optimized"
  }

  assert {
    condition     = aws_instance.this.iam_instance_profile == "LabInstanceProfile"
    error_message = "EC2 phải gắn IAM instance profile LabInstanceProfile"
  }
}

run "tc05b_private_ec2" {
  command = apply

  module {
    source = "./modules/ec2"
  }

  variables {
    name                = "test-private"
    role                = "private"
    ami_id              = "ami-0123456789abcdef0"
    subnet_id           = run.tc01_vpc.private_subnet_ids[0]
    security_group_ids  = [run.tc04_security_groups.private_ec2_sg_id]
    key_name            = "vockey"
    associate_public_ip = false
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == false
    error_message = "Private EC2 KHÔNG được có Public IP"
  }

  assert {
    condition     = aws_instance.this.subnet_id == var.subnet_id
    error_message = "Private EC2 phải nằm trong Private Subnet"
  }

  assert {
    condition     = contains(aws_instance.this.vpc_security_group_ids, var.security_group_ids[0])
    error_message = "Private EC2 phải gắn Private EC2 SG"
  }
}

# --------------------------------------------------------------------------- #
# TC-07: VPC bật Flow Logs ghi ra S3 (CKV2_AWS_11)
# (đặt cuối file vì chạy lại module vpc với state riêng)
# --------------------------------------------------------------------------- #
run "tc07_vpc_flow_logs" {
  command = apply

  module {
    source = "./modules/vpc"
  }

  variables {
    name                 = "test-fl"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_cidrs  = ["10.0.1.0/24"]
    private_subnet_cidrs = ["10.0.2.0/24"]
    azs                  = ["us-east-1a"]
    enable_flow_logs     = true
    flow_logs_bucket_arn = run.tc01c_flow_logs_bucket.bucket_arn
  }

  assert {
    condition     = aws_flow_log.this[0].vpc_id == aws_vpc.this.id && aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "Flow Log phải ghi toàn bộ traffic (ALL) của VPC"
  }

  assert {
    condition     = aws_flow_log.this[0].log_destination_type == "s3" && aws_flow_log.this[0].log_destination == var.flow_logs_bucket_arn
    error_message = "Flow Log phải ghi vào S3 bucket chỉ định"
  }
}
