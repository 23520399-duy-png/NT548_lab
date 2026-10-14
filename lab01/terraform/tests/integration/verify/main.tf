###############################################################################
# Module phụ trợ cho integration test: đọc lại trạng thái THẬT trên AWS
# bằng data sources để test assert.
###############################################################################

variable "vpc_id" { type = string }
variable "internet_gateway_id" { type = string }
variable "nat_gateway_id" { type = string }
variable "public_route_table_id" { type = string }
variable "private_route_table_id" { type = string }
variable "public_instance_id" { type = string }
variable "private_instance_id" { type = string }

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_internet_gateway" "this" {
  internet_gateway_id = var.internet_gateway_id
}

data "aws_nat_gateway" "this" {
  id = var.nat_gateway_id
}

data "aws_route_table" "public" {
  route_table_id = var.public_route_table_id
}

data "aws_route_table" "private" {
  route_table_id = var.private_route_table_id
}

data "aws_instance" "public" {
  instance_id = var.public_instance_id
}

data "aws_instance" "private" {
  instance_id = var.private_instance_id
}

output "igw_attached_vpc" {
  value = data.aws_internet_gateway.this.attachments[0].vpc_id
}

output "public_default_route_gw" {
  value = one([for r in data.aws_route_table.public.routes : r.gateway_id if r.cidr_block == "0.0.0.0/0"])
}

output "private_default_route_nat" {
  value = one([for r in data.aws_route_table.private.routes : r.nat_gateway_id if r.cidr_block == "0.0.0.0/0"])
}
