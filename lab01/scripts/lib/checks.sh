#!/usr/bin/env bash
###############################################################################
# Bộ test case dùng chung (AWS CLI + SSH) để kiểm tra hạ tầng SAU KHI DEPLOY.
# Được gọi bởi scripts/verify-terraform.sh và scripts/verify-cloudformation.sh
#
# Biến môi trường đầu vào (wrapper sẽ set):
#   VPC_ID PUBLIC_SUBNET_ID PRIVATE_SUBNET_ID IGW_ID DEFAULT_SG_ID NAT_GW_ID
#   NAT_PUBLIC_IP PUBLIC_RT_ID PRIVATE_RT_ID PUBLIC_SG_ID PRIVATE_SG_ID
#   PUBLIC_INSTANCE_ID PRIVATE_INSTANCE_ID PUBLIC_IP PRIVATE_IP
#   ALLOWED_SSH_CIDR  KEY_FILE (mặc định ~/.ssh/labsuser.pem)  AWS_REGION
###############################################################################

PASS=0
FAIL=0
SKIP=0
KEY_FILE="${KEY_FILE:-$HOME/.ssh/labsuser.pem}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1  (got: '${2:-}')"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}[SKIP]${NC} $1"; SKIP=$((SKIP + 1)); }

# expect "<mô tả>" "<giá trị thực tế>" "<giá trị mong đợi>"
expect() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "$2"; fi
}

q() { aws "$@" --output text 2>/dev/null; }

SSH_OPTS=(-i "$KEY_FILE" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10 -o BatchMode=yes -o LogLevel=ERROR)

ssh_public() { ssh "${SSH_OPTS[@]}" "ec2-user@${PUBLIC_IP}" "$@"; }
ssh_private() {
  ssh "${SSH_OPTS[@]}" \
    -o "ProxyCommand=ssh ${SSH_OPTS[*]} -W %h:%p ec2-user@${PUBLIC_IP}" \
    "ec2-user@${PRIVATE_IP}" "$@"
}

run_all_checks() {
  echo "================ TC-01: VPC ================"
  expect "VPC $VPC_ID ở trạng thái available" \
    "$(q ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].State')" "available"

  echo "================ TC-02: Subnets ================"
  expect "Public Subnet thuộc VPC" \
    "$(q ec2 describe-subnets --subnet-ids "$PUBLIC_SUBNET_ID" --query 'Subnets[0].VpcId')" "$VPC_ID"
  expect "Public Subnet tự gán Public IP (MapPublicIpOnLaunch=True)" \
    "$(q ec2 describe-subnets --subnet-ids "$PUBLIC_SUBNET_ID" --query 'Subnets[0].MapPublicIpOnLaunch')" "True"
  expect "Private Subnet thuộc VPC" \
    "$(q ec2 describe-subnets --subnet-ids "$PRIVATE_SUBNET_ID" --query 'Subnets[0].VpcId')" "$VPC_ID"
  expect "Private Subnet KHÔNG tự gán Public IP" \
    "$(q ec2 describe-subnets --subnet-ids "$PRIVATE_SUBNET_ID" --query 'Subnets[0].MapPublicIpOnLaunch')" "False"

  echo "================ TC-03: Internet Gateway ================"
  expect "IGW gắn vào VPC" \
    "$(q ec2 describe-internet-gateways --internet-gateway-ids "$IGW_ID" --query 'InternetGateways[0].Attachments[0].VpcId')" "$VPC_ID"
  expect "IGW attachment state = available" \
    "$(q ec2 describe-internet-gateways --internet-gateway-ids "$IGW_ID" --query 'InternetGateways[0].Attachments[0].State')" "available"

  echo "================ TC-04: Default Security Group ================"
  expect "Default SG thuộc VPC" \
    "$(q ec2 describe-security-groups --group-ids "$DEFAULT_SG_ID" --query 'SecurityGroups[0].VpcId')" "$VPC_ID"
  expect "Default SG không mở inbound ra 0.0.0.0/0" \
    "$(q ec2 describe-security-groups --group-ids "$DEFAULT_SG_ID" \
      --query "length(SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']])")" "0"

  echo "================ TC-05: NAT Gateway ================"
  expect "NAT Gateway state = available" \
    "$(q ec2 describe-nat-gateways --nat-gateway-ids "$NAT_GW_ID" --query 'NatGateways[0].State')" "available"
  expect "NAT Gateway nằm trong Public Subnet" \
    "$(q ec2 describe-nat-gateways --nat-gateway-ids "$NAT_GW_ID" --query 'NatGateways[0].SubnetId')" "$PUBLIC_SUBNET_ID"

  echo "================ TC-06: Public Route Table ================"
  expect "Public RT: 0.0.0.0/0 -> IGW" \
    "$(q ec2 describe-route-tables --route-table-ids "$PUBLIC_RT_ID" \
      --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId | [0]")" "$IGW_ID"
  expect "Public RT được gắn với Public Subnet" \
    "$(q ec2 describe-route-tables --route-table-ids "$PUBLIC_RT_ID" \
      --query "RouteTables[0].Associations[?SubnetId=='$PUBLIC_SUBNET_ID'].SubnetId | [0]")" "$PUBLIC_SUBNET_ID"

  echo "================ TC-07: Private Route Table ================"
  expect "Private RT: 0.0.0.0/0 -> NAT Gateway" \
    "$(q ec2 describe-route-tables --route-table-ids "$PRIVATE_RT_ID" \
      --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId | [0]")" "$NAT_GW_ID"
  expect "Private RT được gắn với Private Subnet" \
    "$(q ec2 describe-route-tables --route-table-ids "$PRIVATE_RT_ID" \
      --query "RouteTables[0].Associations[?SubnetId=='$PRIVATE_SUBNET_ID'].SubnetId | [0]")" "$PRIVATE_SUBNET_ID"

  echo "================ TC-08: Public EC2 Security Group ================"
  expect "Public SG chỉ có 1 inbound rule" \
    "$(q ec2 describe-security-groups --group-ids "$PUBLIC_SG_ID" --query 'length(SecurityGroups[0].IpPermissions)')" "1"
  expect "Public SG inbound là TCP/22" \
    "$(q ec2 describe-security-groups --group-ids "$PUBLIC_SG_ID" \
      --query 'join(`,`, [SecurityGroups[0].IpPermissions[0].IpProtocol, to_string(SecurityGroups[0].IpPermissions[0].FromPort), to_string(SecurityGroups[0].IpPermissions[0].ToPort)])')" "tcp,22,22"
  expect "Public SG chỉ cho SSH từ $ALLOWED_SSH_CIDR" \
    "$(q ec2 describe-security-groups --group-ids "$PUBLIC_SG_ID" --query 'SecurityGroups[0].IpPermissions[0].IpRanges[0].CidrIp')" "$ALLOWED_SSH_CIDR"

  echo "================ TC-09: Private EC2 Security Group ================"
  expect "Private SG KHÔNG có rule theo CIDR (chỉ theo SG)" \
    "$(q ec2 describe-security-groups --group-ids "$PRIVATE_SG_ID" \
      --query 'length(SecurityGroups[0].IpPermissions[].IpRanges[])')" "0"
  expect "Private SG cho SSH(22) từ Public EC2 SG" \
    "$(q ec2 describe-security-groups --group-ids "$PRIVATE_SG_ID" \
      --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].UserIdGroupPairs[0].GroupId | [0]")" "$PUBLIC_SG_ID"

  echo "================ TC-10: EC2 Instances ================"
  expect "Public EC2 đang running" \
    "$(q ec2 describe-instances --instance-ids "$PUBLIC_INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name')" "running"
  expect "Public EC2 nằm trong Public Subnet" \
    "$(q ec2 describe-instances --instance-ids "$PUBLIC_INSTANCE_ID" --query 'Reservations[0].Instances[0].SubnetId')" "$PUBLIC_SUBNET_ID"
  expect "Private EC2 đang running" \
    "$(q ec2 describe-instances --instance-ids "$PRIVATE_INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name')" "running"
  expect "Private EC2 nằm trong Private Subnet" \
    "$(q ec2 describe-instances --instance-ids "$PRIVATE_INSTANCE_ID" --query 'Reservations[0].Instances[0].SubnetId')" "$PRIVATE_SUBNET_ID"
  expect "Private EC2 KHÔNG có Public IP" \
    "$(q ec2 describe-instances --instance-ids "$PRIVATE_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress')" "None"
  expect "EC2 bắt buộc IMDSv2" \
    "$(q ec2 describe-instances --instance-ids "$PRIVATE_INSTANCE_ID" --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens')" "required"

  echo "================ TC-11..13: Kết nối thực tế (SSH) ================"
  if [[ ! -f "$KEY_FILE" ]]; then
    skip "Không thấy key $KEY_FILE -> bỏ qua test SSH"
  else
    if ssh_public 'echo ok' 2>/dev/null | grep -q ok; then
      pass "TC-11: SSH từ máy bạn -> Public EC2 ($PUBLIC_IP)"
    else
      fail "TC-11: SSH từ máy bạn -> Public EC2 ($PUBLIC_IP)" "timeout/refused (EC2 vừa tạo cần ~1 phút để boot)"
    fi

    if ssh_private 'hostname' 2>/dev/null | grep -q .; then
      pass "TC-12: SSH Public EC2 (bastion) -> Private EC2 ($PRIVATE_IP)"
    else
      fail "TC-12: SSH Public EC2 (bastion) -> Private EC2 ($PRIVATE_IP)" "timeout/refused"
    fi

    local egress_ip
    egress_ip="$(ssh_private 'curl -s --max-time 10 https://checkip.amazonaws.com' 2>/dev/null | tr -d '[:space:]')"
    expect "TC-13: Private EC2 ra Internet qua NAT (IP đi ra = NAT EIP)" "$egress_ip" "$NAT_PUBLIC_IP"
  fi

  echo "==========================================================="
  echo -e "Kết quả: ${GREEN}${PASS} PASS${NC}, ${RED}${FAIL} FAIL${NC}, ${YELLOW}${SKIP} SKIP${NC}"
  [[ $FAIL -eq 0 ]]
}
