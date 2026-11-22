#!/usr/bin/env bash
###############################################################################
# Dựng toàn bộ môi trường CI/CD local cho Câu 3 (chạy trong WSL2 + Docker Desktop):
#   1. Local registry (localhost:5001) + cụm Kubernetes kind "nt548"
#   2. SonarQube + PostgreSQL, đổi mật khẩu admin, sinh token, tạo webhook
#   3. Build image Jenkins và khởi động Jenkins (JCasC tự tạo job pipeline)
#
#   cd lab02/microservices/jenkins
#   cp .env.example .env && nano .env      # điền GITHUB_TOKEN, mật khẩu
#   ./scripts/setup.sh
###############################################################################
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=nt548
REG_NAME=kind-registry
REG_PORT=5001

need() { command -v "$1" >/dev/null 2>&1 || { echo "!! Thiếu lệnh '$1' – xem README mục Cài đặt"; exit 1; }; }
need docker; need kind; need kubectl; need curl; need jq

[[ -f .env ]] || { echo "!! Chưa có file .env -> cp .env.example .env rồi điền thông tin"; exit 1; }
set -a; source .env; set +a
[[ -n "${GITHUB_TOKEN:-}" ]] || echo "!! Cảnh báo: GITHUB_TOKEN trống – Jenkins không đọc được repo private"

set_env() { # set_env KEY VALUE -> ghi/ghi đè vào .env
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}

###############################################################################
echo "===== [1/4] Local registry + kind cluster ====="
if [[ "$(docker inspect -f '{{.State.Running}}' "$REG_NAME" 2>/dev/null || true)" != "true" ]]; then
  docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --network bridge \
    --name "$REG_NAME" registry:2
fi

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --config kind-config.yaml --wait 120s
fi

# Mỗi node: localhost:5001 -> http://kind-registry:5000
for node in $(kind get nodes --name "$CLUSTER"); do
  docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REG_PORT}"
  printf '[host."http://%s:5000"]\n' "$REG_NAME" | \
    docker exec -i "$node" cp /dev/stdin "/etc/containerd/certs.d/localhost:${REG_PORT}/hosts.toml"
done

if [[ "$(docker inspect -f '{{json .NetworkSettings.Networks.kind}}' "$REG_NAME")" == "null" ]]; then
  docker network connect kind "$REG_NAME"
fi

kubectl --context "kind-${CLUSTER}" apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
YAML

# kubeconfig dùng địa chỉ nội bộ (nt548-control-plane:6443) cho Jenkins
kind get kubeconfig --name "$CLUSTER" --internal > kubeconfig
chmod 644 kubeconfig

###############################################################################
echo "===== [2/4] SonarQube ====="
docker compose up -d sonar-db sonarqube

echo -n ">> Đợi SonarQube khởi động (2-4 phút)"
for _ in $(seq 1 90); do
  status="$(curl -s http://localhost:9000/api/system/status | jq -r .status 2>/dev/null || true)"
  [[ "$status" == "UP" ]] && break
  echo -n "."; sleep 5
done
echo " $status"
[[ "$status" == "UP" ]] || { echo "!! SonarQube chưa UP – xem: docker compose logs sonarqube"; exit 1; }

SQ=http://localhost:9000
# Đổi mật khẩu mặc định admin/admin (bỏ qua nếu đã đổi)
if curl -s -o /dev/null -w '%{http_code}' -u admin:admin "$SQ/api/authentication/validate" | grep -q 200 && \
   [[ "$(curl -s -u admin:admin "$SQ/api/authentication/validate" | jq -r .valid)" == "true" ]]; then
  curl -sf -u admin:admin -X POST "$SQ/api/users/change_password" \
    --data-urlencode "login=admin" --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=${SONAR_ADMIN_PASSWORD}" >/dev/null
  echo ">> Đã đổi mật khẩu admin SonarQube"
fi
AUTH="admin:${SONAR_ADMIN_PASSWORD}"

# Sinh token mới cho Jenkins
curl -s -u "$AUTH" -X POST "$SQ/api/user_tokens/revoke" --data-urlencode "name=jenkins" >/dev/null || true
TOKEN="$(curl -sf -u "$AUTH" -X POST "$SQ/api/user_tokens/generate" \
  --data-urlencode "name=jenkins" --data-urlencode "type=GLOBAL_ANALYSIS_TOKEN" | jq -r .token)"
[[ -n "$TOKEN" && "$TOKEN" != "null" ]] || { echo "!! Không sinh được token SonarQube"; exit 1; }
set_env SONAR_TOKEN "$TOKEN"
echo ">> Đã sinh token SonarQube -> .env"

# Webhook để Jenkins nhận kết quả Quality Gate (waitForQualityGate)
if ! curl -s -u "$AUTH" "$SQ/api/webhooks/list" | jq -e '.webhooks[] | select(.name=="jenkins")' >/dev/null; then
  curl -sf -u "$AUTH" -X POST "$SQ/api/webhooks/create" \
    --data-urlencode "name=jenkins" --data-urlencode "url=http://jenkins:8080/sonarqube-webhook/" >/dev/null
  echo ">> Đã tạo webhook SonarQube -> Jenkins"
fi

###############################################################################
echo "===== [3/4] Jenkins ====="
DOCKER_GID="$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock alpine:3 stat -c '%g' /var/run/docker.sock)"
set_env DOCKER_GID "$DOCKER_GID"
docker compose build jenkins
docker compose up -d jenkins

echo -n ">> Đợi Jenkins khởi động"
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/login || true)"
  [[ "$code" == "200" ]] && break
  echo -n "."; sleep 5
done
echo " HTTP $code"

###############################################################################
echo "===== [4/4] Kiểm tra ====="
docker compose exec -T jenkins bash -c 'docker version --format "docker {{.Server.Version}}" && kubectl get nodes && trivy --version | head -1 && sonar-scanner --version | grep -m1 SonarScanner'

cat <<MSG

=============================================================
 Jenkins   : http://localhost:8080   (user: ${JENKINS_ADMIN_USER})
 SonarQube : http://localhost:9000   (user: admin)
 Ứng dụng  : http://localhost:30080  (sau khi pipeline chạy xong)
 Job       : nt548-lab02-microservices -> bấm "Build Now"
=============================================================
MSG
