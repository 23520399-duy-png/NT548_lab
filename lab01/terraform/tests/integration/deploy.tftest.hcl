###############################################################################
# INTEGRATION TEST - tạo tài nguyên THẬT trên AWS Academy, kiểm tra, rồi
# TỰ ĐỘNG DESTROY khi test xong (~5-7 phút, NAT Gateway tốn phí theo giờ).
#
#   cd terraform
#   terraform init -test-directory=tests/integration
#   terraform test -test-directory=tests/integration \
#       -var "allowed_ssh_cidr=$(curl -s https://checkip.amazonaws.com)/32"
###############################################################################

variables {
  aws_region = "us-east-1"
}

# Provider dùng chung cho cả root module và module verify
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "nt548-lab01"
      ManagedBy = "Terraform-test"
      Course    = "NT548"
    }
  }
}

run "deploy" {
  command = apply

  assert {
    condition     = startswith(output.vpc_id, "vpc-")
    error_message = "VPC chưa được tạo"
  }

  assert {
    condition     = startswith(output.nat_gateway_id, "nat-")
    error_message = "NAT Gateway chưa được tạo"
  }

  assert {
    condition     = output.public_instance_public_ip != ""
    error_message = "Public EC2 phải có Public IP"
  }
}

run "verify_real_state" {
  command = apply

  module {
    source = "./tests/integration/verify"
  }

  variables {
    vpc_id                 = run.deploy.vpc_id
    internet_gateway_id    = run.deploy.internet_gateway_id
    nat_gateway_id         = run.deploy.nat_gateway_id
    public_route_table_id  = run.deploy.public_route_table_id
    private_route_table_id = run.deploy.private_route_table_id
    public_instance_id     = run.deploy.public_instance_id
    private_instance_id    = run.deploy.private_instance_id
  }

  # IT-01: VPC
  assert {
    condition     = data.aws_vpc.this.state == "available" && data.aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC không ở trạng thái available hoặc sai CIDR"
  }

  # IT-02: Internet Gateway gắn đúng VPC
  assert {
    condition     = output.igw_attached_vpc == var.vpc_id
    error_message = "IGW chưa gắn vào VPC"
  }

  # IT-03: NAT Gateway available
  assert {
    condition     = data.aws_nat_gateway.this.state == "available"
    error_message = "NAT Gateway chưa available"
  }

  # IT-04: Route Tables
  assert {
    condition     = output.public_default_route_gw == var.internet_gateway_id
    error_message = "Public RT không có route 0.0.0.0/0 -> IGW"
  }

  assert {
    condition     = output.private_default_route_nat == var.nat_gateway_id
    error_message = "Private RT không có route 0.0.0.0/0 -> NAT"
  }

  # IT-05: EC2
  assert {
    condition     = data.aws_instance.public.instance_state == "running" && data.aws_instance.public.public_ip != ""
    error_message = "Public EC2 phải running và có Public IP"
  }

  assert {
    condition     = data.aws_instance.private.instance_state == "running" && data.aws_instance.private.public_ip == ""
    error_message = "Private EC2 phải running và KHÔNG có Public IP"
  }

  assert {
    condition     = data.aws_instance.private.metadata_options[0].http_tokens == "required"
    error_message = "EC2 phải bắt buộc IMDSv2"
  }
}
