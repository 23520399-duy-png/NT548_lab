#!/usr/bin/env bash
# shellcheck disable=SC2155
# Kiểm tra hạ tầng đã deploy bằng Terraform (chạy sau `terraform apply`).
#   ./scripts/verify-terraform.sh
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"
# shellcheck source=lib/checks.sh
source "$ROOT_DIR/scripts/lib/checks.sh"

tfo() { terraform -chdir="$TF_DIR" output -raw "$1"; }
tfo_first() { terraform -chdir="$TF_DIR" output -json "$1" | tr -d '[]"' | cut -d, -f1; }

echo ">> Đọc outputs từ Terraform state..."
export VPC_ID="$(tfo vpc_id)"
export PUBLIC_SUBNET_ID="$(tfo_first public_subnet_ids)"
export PRIVATE_SUBNET_ID="$(tfo_first private_subnet_ids)"
export IGW_ID="$(tfo internet_gateway_id)"
export DEFAULT_SG_ID="$(tfo default_security_group_id)"
export NAT_GW_ID="$(tfo nat_gateway_id)"
export NAT_PUBLIC_IP="$(tfo nat_public_ip)"
export PUBLIC_RT_ID="$(tfo public_route_table_id)"
export PRIVATE_RT_ID="$(tfo private_route_table_id)"
export PUBLIC_SG_ID="$(tfo public_ec2_sg_id)"
export PRIVATE_SG_ID="$(tfo private_ec2_sg_id)"
export PUBLIC_INSTANCE_ID="$(tfo public_instance_id)"
export PRIVATE_INSTANCE_ID="$(tfo private_instance_id)"
export PUBLIC_IP="$(tfo public_instance_public_ip)"
export PRIVATE_IP="$(tfo private_instance_private_ip)"
export ALLOWED_SSH_CIDR="${ALLOWED_SSH_CIDR:-$(grep -E '^\s*allowed_ssh_cidr' "$TF_DIR/terraform.tfvars" 2>/dev/null | cut -d'"' -f2)}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

run_all_checks
