#!/usr/bin/env bash
###############################################################################
# Đẩy nội dung thư mục lab02/cloudformation lên CodeCommit (nhánh main)
# -> CodePipeline tự phát hiện commit mới và chạy.
#   ./scripts/push-to-codecommit.sh ["commit message"]
# Dùng git-remote-codecommit (GRC) nên làm việc được với credentials tạm thời
# của AWS Academy (không cần tạo Git credentials cho IAM user).
###############################################################################
set -euo pipefail
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="${REPO_NAME:-nt548-lab02-cfn}"
BRANCH="${BRANCH:-main}"
MSG="${1:-Update CloudFormation templates $(date +%F_%T)}"

if ! command -v git-remote-codecommit >/dev/null 2>&1; then
  echo ">> Cài git-remote-codecommit..."
  pip install --user --quiet git-remote-codecommit || pipx install git-remote-codecommit
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REMOTE="codecommit::${AWS_REGION}://${REPO_NAME}"
echo ">> Clone $REMOTE"
if ! git clone --quiet "$REMOTE" "$WORK/repo" 2>/dev/null; then
  mkdir -p "$WORK/repo" && git -C "$WORK/repo" init --quiet
  git -C "$WORK/repo" remote add origin "$REMOTE"
fi
cd "$WORK/repo"
git checkout --quiet -B "$BRANCH"

# Đồng bộ mã (bỏ thư mục sinh ra khi chạy local)
rsync -a --delete --exclude '.git' --exclude 'build/' --exclude 'taskcat_outputs/' \
  --exclude '.taskcat_overrides.yml' "$SRC_DIR"/ ./

git add -A
if git diff --cached --quiet; then
  echo ">> Không có thay đổi để push"
  exit 0
fi
git -c user.name="${GIT_AUTHOR_NAME:-NT548 Student}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-student@gm.uit.edu.vn}" \
    commit --quiet -m "$MSG"
git push --quiet origin "$BRANCH"
echo ">> Đã push lên $REMOTE ($BRANCH): $(git rev-parse --short HEAD)"
echo ">> Theo dõi pipeline: aws codepipeline get-pipeline-state --name ${REPO_NAME}-pipeline"
