# Credentials:
#  - Chạy local : ~/.aws/credentials (copy từ AWS Academy > AWS Details > AWS CLI)
#  - GitHub Actions: GitHub Secrets AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
# KHÔNG hard-code access key trong mã nguồn.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Course    = "NT548"
      Lab       = "lab02"
    }
  }
}
