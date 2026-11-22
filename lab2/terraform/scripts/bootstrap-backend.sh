#!/usr/bin/env bash
###############################################################################
# Tạo S3 bucket chứa Terraform state (chạy 1 lần cho mỗi tài khoản AWS Academy)
#   ./scripts/bootstrap-backend.sh
# Kết quả: in ra tên bucket + tạo file backend.hcl để dùng khi chạy local.
# Bucket này KHÔNG do Terraform quản lý (tránh vòng lặp "state của state").
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-nt548-tfstate-${ACCOUNT_ID}-${AWS_REGION}}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo ">> Bucket $BUCKET đã tồn tại"
else
  echo ">> Tạo bucket $BUCKET"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
  fi
fi

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

cat > backend.hcl <<EOT
bucket       = "${BUCKET}"
key          = "lab02/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOT

echo ">> Xong. Đã ghi backend.hcl"
echo ">> Thêm GitHub Variable: TF_STATE_BUCKET = ${BUCKET}"
