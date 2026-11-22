###############################################################################
# Module: ec2
# Module dùng chung để tạo 1 EC2 instance (gọi 2 lần: public & private).
# Hardening: bắt buộc IMDSv2, mã hoá EBS root volume, không gán Public IP
# cho instance private, detailed monitoring, EBS optimized, gắn IAM instance
# profile (Lab 02 – theo khuyến nghị Checkov).
###############################################################################

resource "aws_instance" "this" {
  # Bastion (Public EC2) bắt buộc có Public IP theo yêu cầu đề bài; instance
  # private truyền associate_public_ip = false nên không có Public IP.
  #checkov:skip=CKV_AWS_88:Public EC2 là bastion host theo thiết kế, SSH chỉ mở cho 1 IP /32

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data
  iam_instance_profile        = var.iam_instance_profile
  monitoring                  = var.detailed_monitoring
  ebs_optimized               = true

  # Bắt buộc IMDSv2 (chống tấn công SSRF lấy credentials từ metadata)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = var.name
    Role = var.role
  }
}
