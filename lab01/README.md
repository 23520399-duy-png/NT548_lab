# NT548 – Lab 01: Terraform & CloudFormation triển khai hạ tầng AWS

Triển khai tự động hạ tầng AWS gồm **VPC, Public/Private Subnet, Internet Gateway, Default
Security Group, NAT Gateway, Route Tables, Security Groups và 2 EC2 instance** bằng
**Terraform** và **AWS CloudFormation**. Mọi dịch vụ được viết dưới dạng **module**
và có **test case** kiểm tra từng dịch vụ.

## Kiến trúc

```
                         Internet
                            │
                   ┌────────┴────────┐
                   │ Internet Gateway│
┌──────────────────┴─────────────────┴───────────────── VPC 10.0.0.0/16 ──┐
│                                                                          │
│  Public Subnet 10.0.1.0/24          Private Subnet 10.0.2.0/24           │
│  RT: 0.0.0.0/0 -> IGW               RT: 0.0.0.0/0 -> NAT GW              │
│  ┌───────────────┐  SSH :22         ┌────────────────┐                   │
│  │ Public EC2    │ ───────────────► │ Private EC2    │                   │
│  │ (bastion)     │  (chỉ từ SG      │ (không Public  │                   │
│  │ SG: 22 từ     │   Public EC2)    │  IP)           │──┐                │
│  │ IP của bạn/32 │                  └────────────────┘  │ ra Internet    │
│  └───────────────┘                                      │                │
│  ┌───────────────┐ ◄────────────────────────────────────┘                │
│  │ NAT Gateway   │ (Elastic IP)                                          │
│  └───────────────┘                                                       │
└──────────────────────────────────────────────────────────────────────────┘
```

## Cấu trúc thư mục

```
.
├── terraform/
│   ├── main.tf  variables.tf  outputs.tf  providers.tf  versions.tf
│   ├── terraform.tfvars.example
│   ├── modules/
│   │   ├── vpc/              # VPC, Subnets, IGW, Default SG
│   │   ├── nat_gateway/      # EIP + NAT Gateway
│   │   ├── route_tables/     # Public RT (->IGW), Private RT (->NAT)
│   │   ├── security_groups/  # Public EC2 SG, Private EC2 SG
│   │   └── ec2/              # Module EC2 dùng chung (public & private)
│   └── tests/
│       ├── unit/             # terraform test + mock provider (offline, 0đ)
│       └── integration/      # terraform test tạo tài nguyên thật rồi tự destroy
├── cloudformation/
│   ├── main.yaml             # Root stack (nested stacks)
│   ├── modules/              # vpc / nat-gateway / route-tables / security-groups / ec2
│   ├── deploy.sh             # package (upload S3) + deploy
│   └── delete.sh
├── scripts/
│   ├── lint-all.sh           # fmt, validate, unit test, cfn-lint
│   ├── verify-terraform.sh   # test case AWS CLI + SSH sau khi apply
│   ├── verify-cloudformation.sh
│   └── lib/checks.sh         # bộ test case dùng chung
└── docs/SETUP-WSL.md         # hướng dẫn cài môi trường WSL + AWS Academy
```

## Yêu cầu

- WSL2 Ubuntu, Terraform ≥ 1.7, AWS CLI v2, cfn-lint, git — xem **[docs/SETUP-WSL.md](docs/SETUP-WSL.md)**
- AWS Academy Learner Lab đã *Start Lab*, credentials đã dán vào `~/.aws/credentials`
- Key `labsuser.pem` tại `~/.ssh/labsuser.pem` (chmod 400)

---

## Phần 1 – Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# sửa allowed_ssh_cidr = "<IP của bạn>/32"   (curl -s https://checkip.amazonaws.com)

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

SSH thử:

```bash
eval "$(terraform output -raw ssh_public_command)"     # vào Public EC2
eval "$(terraform output -raw ssh_private_command)"    # vào Private EC2 qua bastion
```

> Hoặc dùng ssh-agent: `eval $(ssh-agent) && ssh-add ~/.ssh/labsuser.pem`
> rồi `ssh -A -J ec2-user@<PUBLIC_IP> ec2-user@<PRIVATE_IP>`.

Huỷ tài nguyên:

```bash
terraform destroy
```

## Phần 2 – CloudFormation

CloudFormation dùng **Nested Stacks** để mô-đun hoá: mỗi file trong `cloudformation/modules/`
là một module, `main.yaml` ghép các module lại. `deploy.sh` tự tạo S3 bucket, chạy
`aws cloudformation package` (upload module lên S3) rồi `aws cloudformation deploy`.

```bash
cd cloudformation
chmod +x deploy.sh delete.sh
./deploy.sh                                   # tự lấy IP hiện tại làm AllowedSshCidr
# hoặc: ALLOWED_SSH_CIDR=1.2.3.4/32 ./deploy.sh

./delete.sh                                   # xoá stack
DELETE_BUCKET=true ./delete.sh                # xoá cả bucket chứa template
```

> CloudFormation dùng VPC `10.10.0.0/16` để không trùng với bản Terraform (`10.0.0.0/16`)
> nếu chạy song song.

---

## Phần 3 – Test cases

### 3.1. Kiểm tra tĩnh + Unit test (offline, không tốn tiền)

```bash
chmod +x scripts/*.sh cloudformation/*.sh   # chỉ cần làm 1 lần
./scripts/lint-all.sh
```

Hoặc chạy riêng unit test Terraform:

```bash
cd terraform
terraform init -test-directory=tests/unit
terraform test -test-directory=tests/unit
```

| Test | Module | Nội dung kiểm tra |
|---|---|---|
| tc01_vpc | vpc | CIDR, DNS, 1 public + 1 private subnet, public tự gán IP, private không, IGW gắn VPC, Default SG chỉ cho traffic nội bộ |
| tc01b_vpc_invalid_cidr | vpc | Từ chối CIDR sai định dạng |
| tc02_nat_gateway | nat_gateway | NAT nằm trong Public Subnet, dùng EIP, loại public |
| tc03_route_tables | route_tables | Public RT 0.0.0.0/0→IGW, Private RT 0.0.0.0/0→NAT, association đúng subnet |
| tc04_security_groups | security_groups | Public SG chỉ TCP/22 từ IP chỉ định; Private SG chỉ SSH từ Public SG |
| tc04b_reject_open_ssh | security_groups | Từ chối `allowed_ssh_cidr = 0.0.0.0/0` |
| tc05a/b_*_ec2 | ec2 | Public EC2 có Public IP; Private EC2 không; IMDSv2; EBS mã hoá |
| tc06_full_stack_wiring | root | Ghép module đúng: RT→IGW/NAT, EC2 đúng subnet, SG đúng nguồn |

### 3.2. Integration test Terraform (tạo thật → kiểm tra → tự destroy)

```bash
cd terraform
terraform init -test-directory=tests/integration
terraform test -test-directory=tests/integration \
  -var "allowed_ssh_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

### 3.3. Kiểm tra hạ tầng sau khi deploy (AWS CLI + SSH)

```bash
./scripts/verify-terraform.sh        # sau terraform apply
./scripts/verify-cloudformation.sh   # sau cloudformation/deploy.sh
```

| TC | Dịch vụ | Kiểm tra |
|---|---|---|
| TC-01 | VPC | state = available |
| TC-02 | Subnets | thuộc VPC; public MapPublicIpOnLaunch=True, private=False |
| TC-03 | Internet Gateway | gắn vào VPC, state available |
| TC-04 | Default SG | thuộc VPC, không mở 0.0.0.0/0 |
| TC-05 | NAT Gateway | available, nằm ở Public Subnet |
| TC-06 | Public RT | 0.0.0.0/0 → IGW, gắn Public Subnet |
| TC-07 | Private RT | 0.0.0.0/0 → NAT, gắn Private Subnet |
| TC-08 | Public EC2 SG | chỉ 1 rule TCP/22 từ IP của bạn |
| TC-09 | Private EC2 SG | không có rule CIDR, SSH chỉ từ Public EC2 SG |
| TC-10 | EC2 | 2 instance running, đúng subnet, private không có Public IP, IMDSv2 |
| TC-11 | Kết nối | SSH từ máy bạn → Public EC2 |
| TC-12 | Kết nối | SSH Public EC2 → Private EC2 |
| TC-13 | Kết nối | Private EC2 ra Internet, IP đi ra = Elastic IP của NAT |

---

## Bảo mật đã áp dụng

- SSH vào Public EC2 chỉ từ **1 IP /32**; có validation chặn `0.0.0.0/0` (Terraform `validation`, CloudFormation `Rules`).
- Private EC2 **không có Public IP**, chỉ nhận SSH/ICMP từ **Security Group** của Public EC2 (không theo CIDR).
- Default Security Group bị siết: chỉ cho traffic nội bộ, không mở port ra Internet.
- EC2 bắt buộc **IMDSv2**, **EBS root volume mã hoá**.
- Không hard-code credentials; `terraform.tfvars`, `*.tfstate`, `*.pem` nằm trong `.gitignore`.

## Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `ExpiredToken` / `InvalidClientTokenId` | Lab hết giờ → Start Lab, copy lại credentials |
| SSH timeout vào Public EC2 | IP đổi → cập nhật `allowed_ssh_cidr` rồi apply lại; hoặc EC2 chưa boot xong (đợi ~1 phút) |
| `UNPROTECTED PRIVATE KEY FILE` | `chmod 400 ~/.ssh/labsuser.pem` (đừng dùng key ở `/mnt/c`) |
| `InvalidKeyPair.NotFound: vockey` | Sai region, phải dùng `us-east-1` |
| Destroy bị treo ở NAT/EIP | Đợi NAT xoá xong (~1–2 phút), chạy lại `terraform destroy` |
