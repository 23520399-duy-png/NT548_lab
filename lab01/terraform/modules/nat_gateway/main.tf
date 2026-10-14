###############################################################################
# Module: nat_gateway
# Elastic IP + NAT Gateway đặt trong Public Subnet.
# Private Subnet đi ra Internet qua NAT, nhưng Internet KHÔNG thể chủ động
# kết nối ngược vào -> vừa có Internet vừa giữ được tính bảo mật.
###############################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = var.public_subnet_id
  connectivity_type = "public"

  tags = {
    Name = "${var.name}-nat-gw"
  }
}
