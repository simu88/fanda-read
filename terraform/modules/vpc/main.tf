#-----------------------------네트워크 구성--------------------------------
# vpc
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }

  lifecycle {
    #prevent_destroy = true
  }
}

# public_subnets
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

# private_subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]

  # EKS용 서브넷과, DB서브넷을 분리 하는 것이 좋으나 임시로 아래와 같이 설정
  tags = merge(
    {
      # 모든 서브넷에 공통으로 적용될 태그들
      # Name 태그는 4개의 모든 서브넷에 각각 다르게 적용됩니다.
      Name = "eks-private-${count.index}"
    },
     (count.index < 2 ? {
      # EKS가 내부용 로드 밸런서를 생성할 수 있도록 허용하는 태그
      "kubernetes.io/role/internal-elb" = "1"
      
      # (선택사항이지만 권장) 로드 밸런서 컨트롤러 및 다른 도구들이
      # 이 서브넷이 fanda-eks 클러스터 소유임을 알게 하는 태그
      "kubernetes.io/cluster/fanda-eks" = "owned"
      
      # (필수) 카펜터가 노드를 생성할 위치를 발견하도록 하는 태그
      "karpenter.sh/discovery" = "fanda-eks"
      } : {}) # 조건이 거짓이면 빈 맵을 반환하여 아무것도 merge하지 않음
  )
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

# EIP
resource "aws_eip" "nat_eips" {
  count = length(var.azs)
  domain = "vpc"
}

# Nat Gateway
resource "aws_nat_gateway" "nat_gws" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "eks-natgw-${count.index}"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gws[count.index].id
  }

  tags = {
    Name = "eks-private-rt-${count.index}"
  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private[count.index % length(var.azs)].id
}





#--------------------------------Bastion Instance 구성-----------------------------------
# Bastion Host Security Group
resource "aws_security_group" "fanda_bastion_sg" {
  name        = "fanda-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 자신의 IP 주소를 입력하여 SSH 접근을 제한합니다.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fanda-bastion-sg"
  }
}


data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


#============================Bastion===================

# Bastion Host EC2 Instance
resource "aws_instance" "fanda_bastion_instance" {
  ami           = data.aws_ami.ubuntu_2204.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[0].id # Public Subnet에 위치해야 합니다.
  key_name      = "fanda-key-pair" # 미리 생성한 EC2 키 페어 이름을 입력-> AWS콘솔에서 미리 생성을 해야합니다.
  vpc_security_group_ids = [aws_security_group.fanda_bastion_sg.id]
  iam_instance_profile = aws_iam_instance_profile.fanda_ec2_instance_profile.name
  tags = {
    Name = "fanda-bastion-instance"
  }
}

# EC2용 IAM Role
resource "aws_iam_role" "fanda_ec2_msk_role" {
  name = "fanda-ec2-msk-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy
resource "aws_iam_policy" "fanda_ec2_msk_policy" {
  name        = "fanda-ec2-msk-policy"
  description = "Policy for EC2 to access MSK"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "GetBootstrapBrokers"
        Effect   = "Allow"
        Action   = [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster"
        ]
        Resource = var.msk_cluster_arn
      },
      {
        Sid      = "ProducerAccess"
        Effect   = "Allow"
        Action   = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:WriteData"
        ]
        Resource = [
          var.msk_cluster_arn,
          var.topic_arn
        ]
      }
    ]
  })
}

# Role과 Policy 연결
resource "aws_iam_role_policy_attachment" "fanda_ec2_msk_attach" {
  role       = aws_iam_role.fanda_ec2_msk_role.name
  policy_arn = aws_iam_policy.fanda_ec2_msk_policy.arn
}

# 인스턴스 연결
resource "aws_iam_instance_profile" "fanda_ec2_instance_profile" {
  name = "fanda-ec2-instance-profile"
  role = aws_iam_role.fanda_ec2_msk_role.name
}


