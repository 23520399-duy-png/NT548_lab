#!/usr/bin/env bash
###############################################################################
# Tạo 2 S3 bucket bằng AWS CLI (chạy 1 lần cho mỗi tài khoản AWS Academy):
#   1. nt548-tfstate-<account>-<region>        : chứa Terraform state
#   2. <project>-flowlogs-<account>-<region>   : nhận VPC Flow Logs
#   ./scripts/bootstrap-backend.sh
# Vì sao không để Terraform tạo bucket?
#   - Bucket state: tránh vòng lặp "state của state".
#   - Bucket Flow Logs: AWS Academy chặn s3:GetBucketObjectLockConfiguration
#     (Service Control Policy), mà AWS provider luôn gọi API này khi đọc
#     aws_s3_bucket -> terraform apply lỗi AccessDenied.
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
PROJECT_NAME="${PROJECT_NAME:-nt548-lab02}"
BUCKET="${TF_STATE_BUCKET:-nt548-tfstate-${ACCOUNT_ID}-${AWS_REGION}}"
FLOW_BUCKET="${PROJECT_NAME}-flowlogs-${ACCOUNT_ID}-${AWS_REGION}"

create_bucket() { # create_bucket <tên> : tạo (nếu chưa có), chặn public, mã hoá, versioning
  local b="$1"
  if aws s3api head-bucket --bucket "$b" 2>/dev/null; then
    echo ">> Bucket $b đã tồn tại"
  else
    echo ">> Tạo bucket $b"
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$b" >/dev/null
    else
      aws s3api create-bucket --bucket "$b" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
    fi
  fi
  aws s3api put-public-access-block --bucket "$b" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-versioning --bucket "$b" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$b" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
}

create_bucket "$BUCKET"
create_bucket "$FLOW_BUCKET"

# Flow Logs: tự xoá log sau 7 ngày, xoá version cũ sau 1 ngày
aws s3api put-bucket-lifecycle-configuration --bucket "$FLOW_BUCKET" --lifecycle-configuration '{
  "Rules":[{"ID":"expire-flow-logs","Status":"Enabled","Filter":{},
    "Expiration":{"Days":7},
    "NoncurrentVersionExpiration":{"NoncurrentDays":1},
    "AbortIncompleteMultipartUpload":{"DaysAfterInitiation":1}}]}'

cat > backend.hcl <<EOT
bucket       = "${BUCKET}"
key          = "lab02/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOT

echo ">> Xong. Đã ghi backend.hcl"
echo ">> Bucket Flow Logs: ${FLOW_BUCKET}"
echo ">> Thêm GitHub Variable: TF_STATE_BUCKET = ${BUCKET}"
