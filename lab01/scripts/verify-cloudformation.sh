#!/usr/bin/env bash
# shellcheck disable=SC2155
# Kiểm tra hạ tầng đã deploy bằng CloudFormation (chạy sau cloudformation/deploy.sh).
#   ./scripts/verify-cloudformation.sh
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/checks.sh
source "$ROOT_DIR/scripts/lib/checks.sh"

STACK_NAME="${STACK_NAME:-nt548-lab01-cfn}"
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"

echo ">> Kiểm tra trạng thái stack $STACK_NAME..."
STATUS="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].StackStatus' --output text)"
expect "TC-00: Root stack ở trạng thái CREATE_COMPLETE/UPDATE_COMPLETE" \
  "$(echo "$STATUS" | sed 's/UPDATE_COMPLETE/CREATE_COMPLETE/')" "CREATE_COMPLETE"

NESTED_NOT_OK="$(aws cloudformation list-stack-resources --stack-name "$STACK_NAME" \
  --query "length(StackResourceSummaries[?ResourceType=='AWS::CloudFormation::Stack' && !contains(ResourceStatus, 'COMPLETE')])" --output text)"
expect "TC-00: Tất cả nested stack (module) đều COMPLETE" "$NESTED_NOT_OK" "0"

out() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue | [0]" --output text
}

export VPC_ID="$(out VpcId)"
export PUBLIC_SUBNET_ID="$(out PublicSubnetId)"
export PRIVATE_SUBNET_ID="$(out PrivateSubnetId)"
export IGW_ID="$(out InternetGatewayId)"
export DEFAULT_SG_ID="$(out DefaultSecurityGroupId)"
export NAT_GW_ID="$(out NatGatewayId)"
export NAT_PUBLIC_IP="$(out NatPublicIp)"
export PUBLIC_RT_ID="$(out PublicRouteTableId)"
export PRIVATE_RT_ID="$(out PrivateRouteTableId)"
export PUBLIC_SG_ID="$(out PublicEc2SecurityGroupId)"
export PRIVATE_SG_ID="$(out PrivateEc2SecurityGroupId)"
export PUBLIC_INSTANCE_ID="$(out PublicInstanceId)"
export PRIVATE_INSTANCE_ID="$(out PrivateInstanceId)"
export PUBLIC_IP="$(out PublicInstancePublicIp)"
export PRIVATE_IP="$(out PrivateInstancePrivateIp)"
export ALLOWED_SSH_CIDR="$(out AllowedSshCidr)"

run_all_checks
