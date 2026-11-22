###############################################################################
# UNIT TEST cho root module (ghép toàn bộ các module) - chạy OFFLINE với mock.
###############################################################################

mock_provider "aws" {
  # Mock provider sinh chuỗi ngẫu nhiên cho "arn" -> aws_flow_log báo ARN sai.
  # Gán ARN hợp lệ cho S3 bucket giả lập.
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-flowlogs-bucket"
    }
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  # Giá trị giả cho data source tài khoản/region (dùng để đặt tên bucket)
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  allowed_ssh_cidr = "203.0.113.10/32"
}

run "tc06_full_stack_wiring" {
  command = apply

  assert {
    condition     = module.route_tables.public_default_route_target == module.vpc.internet_gateway_id
    error_message = "Public RT phải trỏ default route về IGW của VPC"
  }

  assert {
    condition     = module.route_tables.private_default_route_target == module.nat_gateway.nat_gateway_id
    error_message = "Private RT phải trỏ default route về NAT Gateway"
  }

  assert {
    condition     = module.public_ec2.subnet_id == module.vpc.public_subnet_ids[0]
    error_message = "Public EC2 phải nằm trong Public Subnet"
  }

  assert {
    condition     = module.private_ec2.subnet_id == module.vpc.private_subnet_ids[0]
    error_message = "Private EC2 phải nằm trong Private Subnet"
  }

  assert {
    condition     = module.security_groups.private_ssh_source_sg == module.security_groups.public_ec2_sg_id
    error_message = "Private EC2 chỉ nhận SSH từ Public EC2 SG"
  }

  assert {
    condition     = module.security_groups.public_ssh_cidr == var.allowed_ssh_cidr
    error_message = "Public EC2 chỉ nhận SSH từ IP người dùng"
  }

  assert {
    condition     = length(module.flow_logs_bucket) == 0 && module.vpc.flow_log_traffic_type == "ALL"
    error_message = "VPC Flow Logs phải được bật mặc định, ghi vào bucket có sẵn (không tạo bucket bằng Terraform)"
  }

  assert {
    condition     = output.flow_logs_bucket == "nt548-lab02-flowlogs-123456789012-us-east-1"
    error_message = "Tên bucket Flow Logs phải theo mẫu <project>-flowlogs-<account>-<region>"
  }

  assert {
    condition     = module.public_ec2.iam_instance_profile == "LabInstanceProfile" && module.private_ec2.iam_instance_profile == "LabInstanceProfile"
    error_message = "Cả 2 EC2 phải gắn LabInstanceProfile"
  }
}

# TC-06b: Có thể tắt Flow Logs
run "tc06b_flow_logs_disabled" {
  command = plan

  variables {
    enable_flow_logs = false
  }

  assert {
    condition     = module.vpc.flow_log_id == null && output.flow_logs_bucket == null
    error_message = "enable_flow_logs = false thì không tạo Flow Logs"
  }
}

# TC-06c: Tài khoản AWS thường – Terraform tự tạo bucket Flow Logs
run "tc06c_create_flow_logs_bucket" {
  command = plan

  variables {
    create_flow_logs_bucket = true
  }

  assert {
    condition     = length(module.flow_logs_bucket) == 1
    error_message = "create_flow_logs_bucket = true thì phải tạo bucket bằng module"
  }
}

# TC-06d: Chỉ định tên bucket có sẵn
run "tc06d_existing_bucket_name" {
  command = plan

  variables {
    flow_logs_bucket_name = "my-existing-log-bucket"
  }

  assert {
    condition     = output.flow_logs_bucket == "my-existing-log-bucket"
    error_message = "Phải dùng đúng bucket được chỉ định"
  }
}
