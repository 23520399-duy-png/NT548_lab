#!/usr/bin/env bash
###############################################################################
# Chạy trên máy (WSL) đúng các bước kiểm tra của CodeBuild:
#   cfn-lint (dùng .cfnlintrc.yaml) + taskcat lint
#   ./scripts/lint-local.sh            # offline
#   RUN_TASKCAT=true ./scripts/lint-local.sh   # + taskcat test run (tốn ~15 phút, tạo stack thật)
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

echo "===== [1] cfn-lint ====="
cfn-lint && echo "cfn-lint: OK"

echo "===== [2] taskcat lint ====="
taskcat lint

if aws sts get-caller-identity >/dev/null 2>&1; then
  echo "===== [3] aws cloudformation validate-template ====="
  for f in templates/main.yaml templates/modules/*.yaml pipeline/pipeline.yaml; do
    aws cloudformation validate-template --template-body "file://$f" >/dev/null && echo "  OK  $f"
  done
  if [[ "${RUN_TASKCAT:-false}" == "true" ]]; then
    echo "===== [4] taskcat test run ====="
    taskcat test run --output-directory taskcat_outputs
  fi
else
  echo "===== Bỏ qua validate-template/taskcat test (chưa có AWS credentials) ====="
fi
echo ">> Kiểm tra PASS"
