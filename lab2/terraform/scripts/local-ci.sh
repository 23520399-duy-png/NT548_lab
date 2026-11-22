#!/usr/bin/env bash
###############################################################################
# Chạy lại các bước kiểm tra của GitHub Actions ngay trên máy (WSL), OFFLINE:
#   fmt -> init -> validate -> unit test -> Checkov
#   ./scripts/local-ci.sh
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

echo "===== [1] terraform fmt -check ====="
terraform fmt -check -recursive

echo "===== [2] terraform init (không dùng backend) + validate ====="
terraform init -backend=false -input=false -test-directory=tests/unit >/dev/null
terraform validate

echo "===== [3] terraform test (unit, mock provider) ====="
terraform test -test-directory=tests/unit

echo "===== [4] Checkov ====="
checkov -d . --config-file .checkov.yaml

echo ">> Tất cả kiểm tra đều PASS"
