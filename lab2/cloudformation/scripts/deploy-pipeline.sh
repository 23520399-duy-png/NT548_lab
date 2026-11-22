#!/usr/bin/env bash
###############################################################################
# Triển khai stack CI/CD (CodeCommit + CodeBuild + CodePipeline) – chạy 1 lần.
#   ./scripts/deploy-pipeline.sh
# Biến tuỳ chọn:
#   AWS_REGION (us-east-1) | PIPELINE_STACK (nt548-lab02-pipeline)
#   SOURCE_PROVIDER (CodeCommit | S3) | RUN_TASKCAT (true) | APPROVAL (false)
#   ALLOWED_SSH_CIDR (mặc định: IP public hiện tại /32)
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
PIPELINE_STACK="${PIPELINE_STACK:-nt548-lab02-pipeline}"
SOURCE_PROVIDER="${SOURCE_PROVIDER:-CodeCommit}"
RUN_TASKCAT="${RUN_TASKCAT:-true}"
APPROVAL="${APPROVAL:-false}"
REPO_NAME="${REPO_NAME:-nt548-lab02-cfn}"

if [[ -z "${ALLOWED_SSH_CIDR:-}" ]]; then
  ALLOWED_SSH_CIDR="$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')/32"
fi

# Nếu repo CodeCommit đã có sẵn (chạy lại script) thì không tạo mới
CREATE_REPO=true
if [[ "$SOURCE_PROVIDER" == "CodeCommit" ]] && \
   aws codecommit get-repository --repository-name "$REPO_NAME" >/dev/null 2>&1; then
  if ! aws cloudformation describe-stack-resource --stack-name "$PIPELINE_STACK" \
        --logical-resource-id Repository >/dev/null 2>&1; then
    CREATE_REPO=false
  fi
fi

echo ">> Region: $AWS_REGION | Stack: $PIPELINE_STACK | Source: $SOURCE_PROVIDER"
echo ">> SSH cho phép từ: $ALLOWED_SSH_CIDR | Taskcat: $RUN_TASKCAT"

cfn-lint pipeline/pipeline.yaml 2>/dev/null || true

aws cloudformation deploy \
  --template-file pipeline/pipeline.yaml \
  --stack-name "$PIPELINE_STACK" \
  --parameter-overrides \
      SourceProvider="$SOURCE_PROVIDER" \
      RepositoryName="$REPO_NAME" \
      CreateRepository="$CREATE_REPO" \
      AllowedSshCidr="$ALLOWED_SSH_CIDR" \
      RunTaskcat="$RUN_TASKCAT" \
      RequireManualApproval="$APPROVAL" \
  --tags Course=NT548 Lab=lab02 \
  --no-fail-on-empty-changeset

aws cloudformation describe-stacks --stack-name "$PIPELINE_STACK" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
