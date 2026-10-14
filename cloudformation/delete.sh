#!/usr/bin/env bash
# Xoá toàn bộ stack (và các nested stack) để tránh tốn phí NAT Gateway.
#   cd cloudformation && ./delete.sh
set -euo pipefail

STACK_NAME="${STACK_NAME:-nt548-lab01-cfn}"
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"

echo ">> Xoá stack $STACK_NAME ..."
aws cloudformation delete-stack --stack-name "$STACK_NAME"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
echo ">> Đã xoá xong."

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${CFN_BUCKET:-nt548-cfn-templates-${ACCOUNT_ID}-${AWS_DEFAULT_REGION}}"
if [[ "${DELETE_BUCKET:-false}" == "true" ]]; then
  aws s3 rb "s3://$BUCKET" --force
  echo ">> Đã xoá bucket $BUCKET"
fi
