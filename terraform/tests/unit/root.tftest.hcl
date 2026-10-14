###############################################################################
# UNIT TEST cho root module (ghép toàn bộ các module) - chạy OFFLINE với mock.
###############################################################################

mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
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
}
