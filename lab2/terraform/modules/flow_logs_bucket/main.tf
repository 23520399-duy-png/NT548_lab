###############################################################################
# Module: flow_logs_bucket
# S3 bucket chứa VPC Flow Logs (resource aws_flow_log nằm trong module vpc).
# Dùng S3 làm đích vì AWS Academy không cho tạo IAM Role (đích CloudWatch Logs
# cần IAM Role cho dịch vụ vpc-flow-logs).
###############################################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_18:Bucket chỉ chứa log, bật access logging cho bucket log sẽ tạo vòng lặp log-của-log
  #checkov:skip=CKV_AWS_144:Không cần replication cross-region cho log của bài lab
  #checkov:skip=CKV2_AWS_62:Không cần event notification cho bucket log
  #checkov:skip=CKV_AWS_145:Flow Logs không ghi được vào bucket SSE-KMS dùng key aws/s3 (không sửa được key policy); dùng SSE-S3 (AES256)

  bucket        = "${var.name}-flowlogs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = true # cho phép terraform destroy xoá luôn log cũ (môi trường lab)

  tags = {
    Name = "${var.name}-flowlogs"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-flow-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
