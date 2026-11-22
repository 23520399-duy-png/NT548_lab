# NT548 – Lab 02: Terraform, CloudFormation, GitHub Actions, CodePipeline và Jenkins

Lab này tự động hoá việc triển khai hạ tầng AWS của **Lab 01** (VPC, Subnet, Internet Gateway, NAT Gateway,
Route Tables, Security Groups, EC2) và dựng quy trình CI/CD cho một ứng dụng microservices.

| Câu | Nội dung | Công cụ | Thư mục |
|---|---|---|---|
| 1 (3đ) | Hạ tầng AWS bằng Terraform, tự động hoá bằng GitHub Actions, kiểm tra bảo mật bằng Checkov | Terraform, GitHub Actions, Checkov | [`terraform/`](terraform), [`.github/workflows/lab02-terraform.yml`](../.github/workflows/lab02-terraform.yml) |
| 2 (3đ) | Hạ tầng AWS bằng CloudFormation, build/deploy bằng CodePipeline lấy mã từ CodeCommit, kiểm tra bằng cfn-lint và Taskcat | CloudFormation, CodeCommit, CodeBuild, CodePipeline, cfn-lint, Taskcat | [`cloudformation/`](cloudformation) |
| 3 (4đ) | CI/CD cho 3 microservice: build, test, SonarQube, Trivy, Docker, Kubernetes | Jenkins, SonarQube, Trivy, Docker, kind (Kubernetes) | [`microservices/`](microservices) |

> Cài đặt công cụ: **[docs/SETUP-WSL.md](docs/SETUP-WSL.md)** (bổ sung cho `lab01/docs/SETUP-WSL.md`).

## Cấu trúc thư mục

```
lab02/
├── terraform/                     # CÂU 1
│   ├── main.tf variables.tf outputs.tf providers.tf versions.tf
│   ├── backend.hcl.example        # cấu hình remote state S3
│   ├── .checkov.yaml              # cấu hình Checkov
│   ├── modules/
│   │   ├── flow_logs_bucket/      # S3 bucket chứa VPC Flow Logs (mới)
│   │   ├── vpc/                   # VPC, Subnets, IGW, Default SG (khoá hết), Flow Logs
│   │   ├── nat_gateway/  route_tables/  security_groups/  ec2/
│   ├── tests/unit/                # 13 test case, chạy offline với mock provider
│   └── scripts/
│       ├── bootstrap-backend.sh   # tạo S3 bucket chứa state (1 lần)
│       └── local-ci.sh            # chạy lại các bước CI trên máy
├── cloudformation/                # CÂU 2 (thư mục này được đẩy lên CodeCommit)
│   ├── templates/main.yaml        # root stack (nested stacks, đọc module từ S3)
│   ├── templates/modules/         # vpc / nat-gateway / route-tables / security-groups / ec2
│   ├── buildspecs/
│   │   ├── buildspec-validate.yml # CodeBuild: cfn-lint + validate + upload template
│   │   └── buildspec-taskcat.yml  # CodeBuild: taskcat test run
│   ├── pipeline/pipeline.yaml     # CodeCommit + 2 CodeBuild + CodePipeline + S3
│   ├── .cfnlintrc.yaml  .taskcat.yml
│   └── scripts/                   # deploy-pipeline / push-to-codecommit / push-to-s3 / lint-local / cleanup
├── microservices/                 # CÂU 3
│   ├── services/
│   │   ├── product-service/       # Python FastAPI + pytest
│   │   ├── order-service/         # Node.js Express + jest
│   │   └── gateway/               # nginx: giao diện web + reverse proxy /api/*
│   ├── k8s/base/                  # Deployment, Service, Namespace (kustomize)
│   ├── Jenkinsfile                # pipeline CI/CD
│   ├── sonar-project.properties
│   ├── docker-compose.yml         # chạy thử app bằng Docker Compose
│   └── jenkins/                   # Jenkins + SonarQube + kind (dựng bằng scripts/setup.sh)
└── docs/SETUP-WSL.md
```

---

## Câu 1 – Terraform + GitHub Actions + Checkov

### 1.1. Kiến trúc pipeline

```
 Pull Request ─┐                                   ┌─> comment kết quả plan lên PR
               ├─> fmt/validate/unit test ─┐       │
 Push main ────┤                           ├─> plan ┴─> apply (chỉ push main) ─> kiểm tra hạ tầng
               └─> Checkov (fail = dừng) ──┘
 Run workflow (tay): plan | apply | destroy
```

Thay đổi so với Lab 01 để **Checkov pass 100%** (69 passed, 0 failed):

| Check | Xử lý |
|---|---|
| CKV2_AWS_11 – VPC Flow Logs | Thêm Flow Logs ghi toàn bộ traffic ra S3 (module `flow_logs_bucket`) |
| CKV2_AWS_12 – Default SG | Default SG bị xoá hết rule (chặn mọi traffic) |
| CKV_AWS_126 / CKV_AWS_135 | EC2 bật detailed monitoring, EBS optimized |
| CKV2_AWS_41 – IAM role cho EC2 | Gắn `LabInstanceProfile` có sẵn của AWS Academy |
| CKV_AWS_394 – AZ cố định | Data source AZ lọc theo `zone-name` (a, b) |
| CKV_AWS_88, CKV_AWS_130 | Ngoại lệ có chủ đích (bastion cần Public IP) – ghi lý do bằng `#checkov:skip` ngay trong code |
| CKV_AWS_24/277, CKV2_AWS_5 | Báo nhầm (nguồn là Security Group, SG gắn qua module) – ghi lý do trong code |

### 1.2. Chuẩn bị (1 lần)

```bash
cd lab02/terraform
./scripts/bootstrap-backend.sh          # tạo bucket nt548-tfstate-<account>-us-east-1 + file backend.hcl
```

Trên GitHub repo → **Settings → Secrets and variables → Actions**:

| Loại | Tên | Giá trị |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` | từ AWS Academy → AWS Details → AWS CLI |
| Secret | `AWS_SECRET_ACCESS_KEY` | như trên |
| Secret | `AWS_SESSION_TOKEN` | như trên |
| Secret | `ALLOWED_SSH_CIDR` | IP của bạn, ví dụ `1.2.3.4/32` (`curl -s https://checkip.amazonaws.com`) |
| Variable | `TF_STATE_BUCKET` | tên bucket script vừa in ra |
| Variable | `AWS_REGION` | (tuỳ chọn) `us-east-1` |

Tạo thêm **Settings → Environments → New environment** tên `aws-academy`
(tuỳ chọn bật *Required reviewers* để duyệt tay trước khi apply).

> ⚠️ Credentials AWS Academy **hết hạn sau ~4 giờ**. Mỗi lần *Start Lab* phải cập nhật lại 3 secret AWS.
> Có thể dùng GitHub CLI: `gh secret set AWS_SESSION_TOKEN --body "..."`.

### 1.3. Chạy

```bash
# Kiểm tra trên máy trước khi push (offline, không tốn tiền)
./scripts/local-ci.sh

# Cách 1: tạo Pull Request -> workflow chạy validate + Checkov + plan, comment plan lên PR
git checkout -b feature/lab02-tf && git push -u origin feature/lab02-tf

# Cách 2: merge/push vào main -> workflow chạy tới apply
# Cách 3: Actions -> "Lab02 - Terraform CI/CD" -> Run workflow -> chọn plan/apply/destroy
```

Chạy Terraform trực tiếp trên máy (không qua GitHub Actions):

```bash
cp terraform.tfvars.example terraform.tfvars    # sửa allowed_ssh_cidr
terraform init -backend-config=backend.hcl
terraform plan -out tfplan && terraform apply tfplan
```

### 1.4. Kiểm tra kết quả

- Tab **Actions**: các job `fmt / validate / unit test`, `Checkov security scan`, `terraform plan`, `terraform apply` đều xanh.
- Job Checkov: log in `Failed checks: 0` (bản chạy thử: 69 passed, 11 skipped có lý do); báo cáo SARIF/JUnit trong mục *Artifacts*.
- **Summary** của job apply có bảng `terraform output` và bước *Kiểm tra nhanh hạ tầng* (VPC available, NAT available, Flow Log ACTIVE, Private EC2 không có Public IP).
- Kiểm tra sâu hơn (SSH bastion → private EC2 → ra Internet qua NAT): dùng lại `lab01/scripts/verify-terraform.sh` sau khi `terraform init -backend-config=backend.hcl`.
- **Xoá hạ tầng**: Actions → Run workflow → `destroy` (NAT Gateway tính phí theo giờ).

---

## Câu 2 – CloudFormation + CodeBuild (cfn-lint, Taskcat) + CodePipeline

### 2.1. Kiến trúc pipeline

```
 CodeCommit (nhánh main)
      │  (polling)
      ▼
 ┌──────────┐   ┌───────────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
 │  Source  │──>│ Validate (CodeBuild)      │──>│ Test (CodeBuild)     │──>│ Deploy               │
 │          │   │ cfn-lint + validate-      │   │ taskcat test run:    │   │ CloudFormation       │
 │          │   │ template, upload module   │   │ tạo 2 stack thật ->  │   │ CREATE_UPDATE stack  │
 │          │   │ lên S3, sinh config.json  │   │ kiểm tra -> xoá      │   │ nt548-lab02-cfn-infra│
 └──────────┘   └───────────────────────────┘   └──────────────────────┘   └──────────────────────┘
```

- AWS Academy **không cho tạo IAM Role** → CodePipeline, CodeBuild và CloudFormation đều dùng `LabRole` có sẵn.
- Template con (nested stack) được đọc từ S3 qua tham số `TemplatesBucketName`/`TemplatesKeyPrefix`, nên cùng một
  template chạy được cả trong CodePipeline (prefix = commit ID) và Taskcat (bucket tự tạo của Taskcat).
- `.taskcat.yml` có 2 test: cấu hình mặc định và dải mạng/loại instance khác.

### 2.2. Kiểm tra trên máy

```bash
cd lab02/cloudformation
./scripts/lint-local.sh                     # cfn-lint + taskcat lint (+ validate-template nếu có credentials)
RUN_TASKCAT=true ./scripts/lint-local.sh    # chạy thêm taskcat test run (tạo stack thật ~15 phút)
```

### 2.3. Triển khai pipeline và đẩy mã lên CodeCommit

```bash
cd lab02/cloudformation
./scripts/deploy-pipeline.sh                # tạo CodeCommit repo + 2 CodeBuild + CodePipeline + S3
./scripts/push-to-codecommit.sh "Lab02: initial commit"   # pipeline tự chạy sau ~1 phút
```

Tuỳ chọn:

```bash
RUN_TASKCAT=false ./scripts/deploy-pipeline.sh   # bỏ bước taskcat cho nhanh khi thử nghiệm
APPROVAL=true ./scripts/deploy-pipeline.sh       # thêm bước duyệt tay trước Deploy
```

> **Nếu tài khoản không dùng được CodeCommit** (lỗi `CodeCommit is not available` khi deploy):
> ```bash
> SOURCE_PROVIDER=S3 ./scripts/deploy-pipeline.sh
> ./scripts/push-to-s3.sh
> ```
> Pipeline giữ nguyên các bước Validate → Test → Deploy, chỉ đổi nguồn mã sang file zip trên S3.

### 2.4. Kiểm tra kết quả

```bash
aws codepipeline get-pipeline-state --name nt548-lab02-cfn-pipeline \
  --query 'stageStates[].[stageName,latestExecution.status]' --output table
aws cloudformation describe-stacks --stack-name nt548-lab02-cfn-infra \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
```

- Console **CodePipeline**: 4 stage Source / Validate / Test / Deploy đều *Succeeded*.
- Console **CodeBuild → Report groups**: báo cáo JUnit `cfn-lint` (0 lỗi).
- Log CodeBuild `nt548-lab02-cfn-taskcat`: 2 test `default`, `custom-network` đều `CREATE_COMPLETE` rồi bị xoá; báo cáo HTML của Taskcat nằm trong artifact `TaskcatReport` (S3).
- Console **CloudFormation**: stack `nt548-lab02-cfn-infra` + 6 nested stack `CREATE_COMPLETE`.
- Kiểm tra kết nối: `STACK_NAME=nt548-lab02-cfn-infra ../../lab01/scripts/verify-cloudformation.sh`.

### 2.5. Dọn dẹp

```bash
./scripts/cleanup.sh                  # xoá stack hạ tầng, stack taskcat sót lại, stack pipeline
DELETE_REPO=true ./scripts/cleanup.sh # xoá luôn CodeCommit repo
```

---

## Câu 3 – Jenkins + SonarQube + Trivy + Docker + Kubernetes

### 3.1. Ứng dụng

```
 Trình duyệt ──> gateway (nginx :8080) ──/api/products──> product-service (FastAPI :8000)
                      │                 ──/api/orders───> order-service (Express :3000) ──> product-service
                      └─ giao diện web tĩnh
```

| Service | Ngôn ngữ | Test | Image |
|---|---|---|---|
| product-service | Python 3.12 / FastAPI | pytest, 9 test, coverage 100% | multi-stage, chạy user 10001 |
| order-service | Node.js 22 / Express 5 | jest + supertest, 16 test, coverage 100% dòng | multi-stage, chạy user không phải root |
| gateway | nginx-unprivileged | – | proxy `/api/*`, header bảo mật |

Manifest Kubernetes tuân thủ **Pod Security Standard "restricted"**: không chạy root, root filesystem chỉ đọc,
bỏ mọi capability, seccomp `RuntimeDefault`, có requests/limits, readiness/liveness probe, rolling update không downtime.

### 3.2. Pipeline Jenkins

```
Checkout ─> Unit test (pytest ║ jest) ─> SonarQube analysis ─> Quality Gate
        ─> Trivy quét mã nguồn ─> Build 3 image (song song) ─> Trivy quét image (CRITICAL = fail)
        ─> Push registry ─> Deploy Kubernetes (kustomize) ─> Smoke test
```

Môi trường (tất cả chạy local trong Docker Desktop, không tốn tiền AWS):

| Thành phần | Địa chỉ |
|---|---|
| Jenkins (JCasC tự cấu hình, có sẵn job) | http://localhost:8080 |
| SonarQube Community + PostgreSQL | http://localhost:9000 |
| Docker registry | `localhost:5001` |
| Kubernetes (kind, 1 control-plane + 1 worker) | context `kind-nt548` |
| Ứng dụng sau khi deploy | http://localhost:30080 |

### 3.3. Dựng môi trường

```bash
cd lab02/microservices/jenkins
cp .env.example .env
nano .env                     # điền GITHUB_TOKEN (xem docs/SETUP-WSL.md mục 4), đổi mật khẩu nếu muốn
./scripts/setup.sh            # ~10 phút lần đầu: kind + registry, SonarQube + token + webhook, build Jenkins
```

Mở http://localhost:8080 → đăng nhập → job **nt548-lab02-microservices** → **Build Now**.
Sau đó Jenkins tự kiểm tra repo mỗi 2 phút (Poll SCM) và chạy lại khi có commit mới.

Chạy thử app không cần Jenkins/Kubernetes:

```bash
cd lab02/microservices && docker compose up -d --build    # http://localhost:8081
```

### 3.4. Kiểm tra kết quả

- **Jenkins → Stage View**: các stage đều xanh; *Test Result* có 25 test; menu **Trivy reports** có báo cáo HTML.
- **SonarQube** → project `NT548 Lab02 - Microservices`: Quality Gate *Passed*, coverage, bugs, code smells.
- **Kubernetes**:
  ```bash
  kubectl --context kind-nt548 -n nt548 get deploy,pods,svc
  kubectl --context kind-nt548 -n nt548 describe deploy gateway | grep Image   # tag = <build>-<commit>
  curl -s http://localhost:30080/api/products | jq
  ```
- Mở http://localhost:30080 → bấm **Đặt 1** để tạo đơn hàng (gateway → order-service → product-service).
- Thử cổng chất lượng: sửa một test cho sai → push → pipeline dừng ở *Unit test*; hoặc hạ base image xuống bản cũ
  có lỗ hổng CRITICAL → pipeline dừng ở *Trivy · quét image*.

### 3.5. Dọn dẹp

```bash
cd lab02/microservices/jenkins
./scripts/teardown.sh                 # dừng Jenkins/SonarQube, giữ dữ liệu
PURGE=true ./scripts/teardown.sh      # xoá cả dữ liệu, cụm kind, registry
```

---

## Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| GitHub Actions: `ExpiredToken` / `The security token included in the request is expired` | Lab Academy hết giờ → Start Lab → cập nhật 3 secret AWS |
| Job plan/apply bị *skipped* | Chưa đặt đủ secrets hoặc variable `TF_STATE_BUCKET` (xem cảnh báo của job *Kiểm tra secrets*) |
| `Error acquiring the state lock` | Lần chạy trước bị huỷ giữa chừng → `terraform force-unlock <ID>` hoặc xoá file `lab02/terraform.tfstate.tflock` trong bucket |
| CodePipeline Deploy lỗi `TemplateURL must be a supported URL` | Bước Validate chưa upload template → xem log CodeBuild `nt548-lab02-cfn-validate` |
| Taskcat lỗi `pkg_resources` | `pipx inject taskcat "setuptools<81"` |
| `git push` CodeCommit hỏi mật khẩu | Dùng script `push-to-codecommit.sh` (URL dạng `codecommit::us-east-1://...`) |
| SonarQube không lên / thoát ngay | Docker Desktop thiếu RAM → tăng lên ≥ 6 GB |
| Jenkins: `permission denied ... docker.sock` | Chạy lại `./scripts/setup.sh` (cập nhật `DOCKER_GID`) rồi `docker compose up -d jenkins` |
| Quality Gate treo tới timeout | Webhook chưa tạo → SonarQube → Administration → Webhooks → thêm `http://jenkins:8080/sonarqube-webhook/` |
| Pod `ErrImagePull` | Registry chưa nối mạng kind → `docker network connect kind kind-registry` |
