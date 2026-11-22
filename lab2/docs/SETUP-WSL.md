# Cài đặt môi trường Lab 02 trên WSL2 (Ubuntu)

> Đã làm theo [`lab01/docs/SETUP-WSL.md`](../../lab01/docs/SETUP-WSL.md) (git, Terraform, AWS CLI v2,
> cfn-lint, credentials AWS Academy, key `labsuser.pem`) thì chỉ cần cài thêm các công cụ dưới đây.

## 1. Terraform ≥ 1.10 + Checkov (Câu 1)

```bash
sudo apt update && sudo apt install --only-upgrade -y terraform
terraform version              # cần >= 1.10 (backend S3 dùng use_lockfile)

pipx install checkov
checkov --version
```

## 2. cfn-lint, Taskcat, git-remote-codecommit (Câu 2)

```bash
pipx install cfn-lint          # bỏ qua nếu đã cài ở Lab 01
pipx install taskcat
pipx inject taskcat "setuptools<81"   # taskcat còn dùng pkg_resources
pipx install git-remote-codecommit    # push lên CodeCommit bằng credentials tạm của Academy

cfn-lint --version && taskcat --version && git-remote-codecommit --help >/dev/null && echo OK
sudo apt install -y rsync zip
```

## 3. Docker Desktop + kind + kubectl (Câu 3)

1. Cài **Docker Desktop for Windows** → *Settings → Resources → WSL integration* → bật cho Ubuntu.
2. *Settings → Resources → Advanced*: cấp **≥ 6 GB RAM** (Jenkins + SonarQube + 2 node Kubernetes).
3. Trong WSL:

```bash
docker version                 # thấy cả Client và Server là OK

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# kind (xem bản mới nhất tại https://github.com/kubernetes-sigs/kind/releases)
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
sudo install -m 0755 kind /usr/local/bin/kind && rm kind

sudo apt install -y jq
kubectl version --client && kind version
```

> Nếu WSL báo thiếu RAM, tạo file `C:\Users\<tên>\.wslconfig`:
> ```ini
> [wsl2]
> memory=8GB
> ```
> rồi chạy `wsl --shutdown` trong PowerShell và mở lại Ubuntu.

## 4. GitHub Personal Access Token (cho Jenkins đọc repo private)

GitHub → *Settings → Developer settings → Personal access tokens → Fine-grained tokens* →
**Generate new token**:

- Repository access: *Only select repositories* → `NT548_lab`
- Permissions → Repository → **Contents: Read-only**

Copy token, dán vào `GITHUB_TOKEN=` trong `lab02/microservices/jenkins/.env`.
