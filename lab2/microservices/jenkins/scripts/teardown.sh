#!/usr/bin/env bash
# Xoá môi trường CI/CD local của Câu 3.
#   ./scripts/teardown.sh            # dừng container, giữ dữ liệu (volume)
#   PURGE=true ./scripts/teardown.sh # xoá luôn volume, cụm kind, registry
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${PURGE:-false}" == "true" ]]; then
  docker compose down -v
  kind delete cluster --name nt548 || true
  docker rm -f kind-registry 2>/dev/null || true
  rm -f kubeconfig
else
  docker compose down
fi
echo ">> Xong"
