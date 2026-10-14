#!/usr/bin/env bash
###############################################################################
# Deploy CloudFormation nested stacks lên AWS Academy.
#   cd cloudformation && ./deploy.sh
# Biến tuỳ chọn:
#   STACK_NAME (mặc định nt548-lab01-cfn)  AWS_REGION (mặc định us-east-1)
#   ALLOWED_SSH_CIDR (mặc định: IP public hiện tại của bạn /32)
###############################################################################
set -euo pipefail
cd "$(dirname "$0")"

STACK_NAME="${STACK_NAME:-nt548-lab01-cfn}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${CFN_BUCKET:-nt548-cfn-templates-${ACCOUNT_ID}-${AWS_REGION}}"

if [[ -z "${ALLOWED_SSH_CIDR:-}" ]]; then
  ALLOWED_SSH_CIDR="$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')/32"
fi
echo ">> Account: $ACCOUNT_ID | Region: $AWS_REGION | Stack: $STACK_NAME"
echo ">> SSH chỉ cho phép từ: $ALLOWED_SSH_CIDR"

# 1. Lint trước khi deploy
if command -v cfn-lint >/dev/null 2>&1; then
  echo ">> cfn-lint..."
  cfn-lint --ignore-checks W3002 -- main.yaml modules/*.yaml
fi

# 2. Bucket S3 chứa template các module (nested stack bắt buộc template nằm trên S3)
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo ">> Tạo S3 bucket $BUCKET"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
  fi
  aws s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

# 3. Package: upload modules/*.yaml lên S3 và thay TemplateURL bằng URL S3
mkdir -p build
aws cloudformation package \
  --template-file main.yaml \
  --s3-bucket "$BUCKET" \
  --s3-prefix "$STACK_NAME" \
  --output-template-file build/packaged.yaml

# 4. Deploy
aws cloudformation deploy \
  --template-file build/packaged.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides AllowedSshCidr="$ALLOWED_SSH_CIDR" \
  --tags Project=nt548-lab01 ManagedBy=CloudFormation Course=NT548 \
  --no-fail-on-empty-changeset

echo ">> Outputs:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
