# Credentials lấy từ ~/.aws/credentials (copy từ AWS Academy > AWS Details > AWS CLI)
# KHÔNG hard-code access key trong mã nguồn.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Course    = "NT548"
    }
  }
}
