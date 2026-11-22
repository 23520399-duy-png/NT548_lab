#!/usr/bin/env bash
###############################################################################
# Xoá toàn bộ tài nguyên Câu 2 (tránh tốn phí NAT Gateway):
#   1. Stack hạ tầng do pipeline tạo
#   2. Stack còn sót lại của taskcat (nếu build bị dừng giữa chừng)
#   3. Stack pipeline (làm rỗng artifact bucket trước)
#   ./scripts/cleanup.sh            # giữ CodeCommit repo
#   DELETE_REPO=true ./scripts/cleanup.sh
###############################################################################
set -euo pipefail
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
PIPELINE_STACK="${PIPELINE_STACK:-nt548-lab02-pipeline}"
INFRA_STACK="${INFRA_STACK:-nt548-lab02-cfn-infra}"
REPO_NAME="${REPO_NAME:-nt548-lab02-cfn}"

delete_stack() {
  local s="$1"
  if aws cloudformation describe-stacks --stack-name "$s" >/dev/null 2>&1; then
    echo ">> Xoá stack $s ..."
    aws cloudformation delete-stack --stack-name "$s"
    aws cloudformation wait stack-delete-complete --stack-name "$s"
  fi
}

delete_stack "$INFRA_STACK"

for s in $(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE CREATE_FAILED ROLLBACK_COMPLETE UPDATE_COMPLETE DELETE_FAILED \
    --query "StackSummaries[?starts_with(StackName,'tCaT-') && ParentId==null].StackName" --output text); do
  delete_stack "$s"
done

BUCKET="$(aws cloudformation describe-stacks --stack-name "$PIPELINE_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='ArtifactBucketName'].OutputValue" --output text 2>/dev/null || true)"
if [[ -n "$BUCKET" && "$BUCKET" != "None" ]]; then
  echo ">> Làm rỗng bucket $BUCKET (kể cả các version cũ)"
  while true; do
    BATCH="$(aws s3api list-object-versions --bucket "$BUCKET" --max-items 500 \
      --query '{Objects: [Versions[].{Key:Key,VersionId:VersionId}, DeleteMarkers[].{Key:Key,VersionId:VersionId}][] | [?Key!=null]}' \
      --output json 2>/dev/null || echo '{"Objects":[]}')"
    [[ "$(echo "$BATCH" | grep -c '"Key"')" -eq 0 ]] && break
    aws s3api delete-objects --bucket "$BUCKET" --delete "$BATCH" >/dev/null
  done
fi
delete_stack "$PIPELINE_STACK"

for b in $(aws s3api list-buckets --query "Buckets[?starts_with(Name,'tcat-')].Name" --output text); do
  echo ">> Xoá bucket taskcat $b"
  aws s3 rb "s3://$b" --force >/dev/null
done

if [[ "${DELETE_REPO:-false}" == "true" ]]; then
  aws codecommit delete-repository --repository-name "$REPO_NAME" >/dev/null && echo ">> Đã xoá repo $REPO_NAME"
fi
echo ">> Dọn dẹp xong"
