terraform {
  # >= 1.10: backend S3 hỗ trợ khoá state bằng file (use_lockfile) – không cần DynamoDB
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state trên S3 (partial configuration).
  # Giá trị bucket/key/region truyền lúc init:
  #   terraform init -backend-config=backend.hcl
  # GitHub Actions truyền qua -backend-config trong workflow.
  # Chạy test/validate offline: terraform init -backend=false
  backend "s3" {}
}
