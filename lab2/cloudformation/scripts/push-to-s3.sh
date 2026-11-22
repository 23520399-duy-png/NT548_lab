#!/usr/bin/env bash
###############################################################################
# (Dự phòng) Dùng khi tài khoản không dùng được CodeCommit:
# nén thư mục lab02/cloudformation thành zip và upload lên S3 Source của pipeline
# (deploy pipeline với SOURCE_PROVIDER=S3).
#   ./scripts/push-to-s3.sh
###############################################################################
set -euo pipefail
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
PIPELINE_STACK="${PIPELINE_STACK:-nt548-lab02-pipeline}"

BUCKET="$(aws cloudformation describe-stacks --stack-name "$PIPELINE_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactBucketName'].OutputValue" --output text)"
KEY="source/nt548-lab02-cfn.zip"

ZIP="$(mktemp -d)/source.zip"
(cd "$SRC_DIR" && zip -qr "$ZIP" . -x 'build/*' 'taskcat_outputs/*' '.taskcat_overrides.yml')
aws s3 cp "$ZIP" "s3://${BUCKET}/${KEY}" --only-show-errors
echo ">> Đã upload s3://${BUCKET}/${KEY} -> pipeline sẽ tự chạy"
