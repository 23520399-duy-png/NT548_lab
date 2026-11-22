###############################################################################
# Module: security_groups
# - Public EC2 SG : chỉ cho SSH (22) từ 1 IP cụ thể (IP của người dùng)
# - Private EC2 SG: chỉ cho SSH (22) + ICMP từ Public EC2 SG (bastion)
###############################################################################

# ----------------------------- Public EC2 SG --------------------------------
resource "aws_security_group" "public_ec2" {
  # SG được gắn vào EC2 ở root module (qua biến security_group_ids) – Checkov
  # không lần theo được tham chiếu xuyên module nên báo nhầm.
  #checkov:skip=CKV2_AWS_5:SG được gắn vào Public EC2 tại root module

  name        = "${var.name}-public-ec2-sg"
  description = "Public EC2: SSH only from allowed IP"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-public-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_ssh" {
  security_group_id = aws_security_group.public_ec2.id
  description       = "SSH from allowed IP only"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "public_all" {
  security_group_id = aws_security_group.public_ec2.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ----------------------------- Private EC2 SG -------------------------------
resource "aws_security_group" "private_ec2" {
  # SG được gắn vào EC2 ở root module (qua biến security_group_ids) – Checkov
  # không lần theo được tham chiếu xuyên module nên báo nhầm.
  #checkov:skip=CKV2_AWS_5:SG được gắn vào Private EC2 tại root module

  name        = "${var.name}-private-ec2-sg"
  description = "Private EC2: SSH/ICMP only from Public EC2 SG"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-private-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_ssh_from_public" {
  # Nguồn là Security Group (referenced_security_group_id), không phải CIDR
  # 0.0.0.0/0 -> Checkov báo nhầm (false positive).
  #checkov:skip=CKV_AWS_24:Nguồn là Public EC2 SG, không mở SSH ra 0.0.0.0/0

  security_group_id            = aws_security_group.private_ec2.id
  description                  = "SSH from Public EC2 (bastion) only"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.public_ec2.id
}

resource "aws_vpc_security_group_ingress_rule" "private_icmp_from_public" {
  #checkov:skip=CKV_AWS_277:Nguồn là Public EC2 SG, không mở ra 0.0.0.0/0
  count = var.allow_icmp_from_public ? 1 : 0

  security_group_id            = aws_security_group.private_ec2.id
  description                  = "ICMP (ping) from Public EC2 only"
  ip_protocol                  = "icmp"
  from_port                    = -1
  to_port                      = -1
  referenced_security_group_id = aws_security_group.public_ec2.id
}

resource "aws_vpc_security_group_egress_rule" "private_all" {
  security_group_id = aws_security_group.private_ec2.id
  description       = "Allow all outbound (via NAT Gateway)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
