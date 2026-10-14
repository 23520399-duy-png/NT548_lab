# Cài đặt môi trường trên WSL2 (Ubuntu) + AWS Academy Learner Lab

> Mở terminal **Ubuntu (WSL)** và chạy lần lượt từng bước. Mỗi bước có lệnh kiểm tra ở cuối.

## Bước 1. Công cụ cơ bản

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl unzip jq gnupg software-properties-common python3-pip pipx shellcheck
pipx ensurepath && source ~/.bashrc
```

## Bước 2. Terraform (repo chính thức HashiCorp)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

terraform version          # cần >= 1.7 (để chạy terraform test với mock_provider)
```

## Bước 3. AWS CLI v2

```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip && sudo ./aws/install
aws --version              # aws-cli/2.x
```

## Bước 4. cfn-lint (lint CloudFormation)

```bash
pipx install cfn-lint
cfn-lint --version
```

## Bước 5. Lấy credentials từ AWS Academy

1. Vào **AWS Academy → Courses → Modules → Launch AWS Academy Learner Lab**.
2. Bấm **Start Lab**, đợi chấm tròn cạnh chữ *AWS* chuyển **xanh lá**.
3. Bấm **AWS Details** → mục *AWS CLI* bấm **Show** → copy cả khối:

   ```
   [default]
   aws_access_key_id=ASIA...
   aws_secret_access_key=...
   aws_session_token=...
   ```

4. Dán vào file credentials trên WSL:

   ```bash
   mkdir -p ~/.aws
   nano ~/.aws/credentials        # dán khối trên, Ctrl+O, Enter, Ctrl+X
   chmod 600 ~/.aws/credentials
   aws configure set region us-east-1
   aws configure set output json
   ```

5. Kiểm tra:

   ```bash
   aws sts get-caller-identity   # thấy "Arn": "...assumed-role/voclabs/..." là OK
   ```

> ⚠️ **Credentials Academy hết hạn sau ~4 giờ** (khi session lab kết thúc). Mỗi lần *Start Lab* lại
> phải copy lại khối credentials mới vào `~/.aws/credentials`. Lỗi `ExpiredToken` /
> `InvalidClientTokenId` = token đã hết hạn.

## Bước 6. Tải SSH key `vockey` (labsuser.pem)

1. Trong **AWS Details** → bấm **Download PEM** → được file `labsuser.pem` (trong `Downloads` của Windows).
2. Copy sang WSL và đặt quyền (file nằm trên `/mnt/c` luôn có quyền 777 nên SSH sẽ từ chối):

   ```bash
   mkdir -p ~/.ssh
   cp /mnt/c/Users/<TEN_USER_WINDOWS>/Downloads/labsuser.pem ~/.ssh/labsuser.pem
   chmod 400 ~/.ssh/labsuser.pem
   ```

## Bước 7. Lấy IP public của bạn (cho Security Group)

```bash
curl -s https://checkip.amazonaws.com     # ví dụ 113.161.xx.yy -> dùng 113.161.xx.yy/32
```

> Nếu bạn đổi mạng (Wi-Fi nhà ↔ trường ↔ 4G) thì IP đổi → phải `terraform apply` /
> `./deploy.sh` lại để cập nhật Security Group, nếu không sẽ SSH timeout.

## Bước 8. Git + GitHub

```bash
git config --global user.name  "Ten Cua Ban"
git config --global user.email "email@example.com"
ssh-keygen -t ed25519 -C "email@example.com"     # Enter hết
cat ~/.ssh/id_ed25519.pub                         # copy -> GitHub > Settings > SSH and GPG keys
ssh -T git@github.com                             # "Hi <user>! You've successfully authenticated"
```

## Lưu ý riêng cho AWS Academy Learner Lab

| Giới hạn | Ảnh hưởng tới bài lab |
|---|---|
| Chỉ dùng được region `us-east-1` và `us-west-2` | Code mặc định `us-east-1` |
| Không tạo được IAM Role/User | Bài này không cần IAM nên OK |
| EC2 chỉ cho loại nano → medium (t2/t3) | Dùng `t3.micro` |
| Key pair có sẵn tên `vockey` | `key_name = "vockey"` |
| Ngân sách ~50–100 USD, **NAT Gateway ~0.045 USD/giờ + phí data** | **Luôn `destroy` khi làm xong!** |
| Khi lab hết giờ, EC2 bị *stop* nhưng NAT Gateway/EIP **vẫn tính tiền** | Không để hạ tầng chạy qua đêm |
