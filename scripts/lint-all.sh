#!/usr/bin/env bash
# Kiểm tra tĩnh (OFFLINE, không tạo tài nguyên): Terraform fmt/validate/unit test + cfn-lint
#   ./scripts/lint-all.sh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "===== [1] terraform fmt ====="
terraform -chdir="$ROOT_DIR/terraform" fmt -check -recursive

echo "===== [2] terraform init + validate ====="
terraform -chdir="$ROOT_DIR/terraform" init -backend=false -input=false \
  -test-directory=tests/unit >/dev/null
terraform -chdir="$ROOT_DIR/terraform" validate

echo "===== [3] terraform test (unit, mock provider) ====="
terraform -chdir="$ROOT_DIR/terraform" test -test-directory=tests/unit

echo "===== [4] cfn-lint ====="
cfn-lint --ignore-checks W3002 -- "$ROOT_DIR"/cloudformation/main.yaml "$ROOT_DIR"/cloudformation/modules/*.yaml
echo "cfn-lint: OK"

if aws sts get-caller-identity >/dev/null 2>&1; then
  echo "===== [5] aws cloudformation validate-template ====="
  for f in "$ROOT_DIR"/cloudformation/main.yaml "$ROOT_DIR"/cloudformation/modules/*.yaml; do
    aws cloudformation validate-template --template-body "file://$f" >/dev/null && echo "  OK  $(basename "$f")"
  done
else
  echo "===== [5] Bỏ qua validate-template (chưa có AWS credentials) ====="
fi

echo ">> Tất cả kiểm tra tĩnh đều PASS"
