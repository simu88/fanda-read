# 1. Jenkins EC2가 사용할 IAM 역할 생성
resource "aws_iam_role" "fanda_jenkins_role" {
  name = "fanda-jenkins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = {
    Name = "fanda-jenkins-role"
  }
}


# ECR 접근 권한 정책
resource "aws_iam_role_policy_attachment" "fanda_ecr_policy" {
  role       = aws_iam_role.fanda_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
# 세션 매니저 사용을 위한 필수 정책 추가
resource "aws_iam_role_policy_attachment" "fanda_ssm_policy" {
  role       = aws_iam_role.fanda_jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# IAM 역할을 EC2 인스턴스에 연결하기 위한 "인스턴스 프로파일" 생성
resource "aws_iam_instance_profile" "fanda_jenkins_profile" {
  # 인스턴스 프로파일 이름과 역할 이름을 일관성 있게 맞추는 것이 좋습니다.
  name = "fanda-jenkins-ec2-profile"
  role = aws_iam_role.fanda_jenkins_role.name
}


# Jenkins EC2 인스턴스용 보안 그룹
resource "aws_security_group" "fanda_jenkins_sg" {
  name        = "fanda-jenkins-sg"
  description = "Security group for Jenkins server in public subnet"
  vpc_id      = var.vpc_id # 기존에 사용하시던 VPC ID

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 자신의 IP 주소를 입력하여 SSH 접근을 제한합니다.
  }

  ingress {
    description = "Allow inbound traffic to Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = [
    #   "118.218.200.33/32", ## 강의실 IP
    #   "118.218.200.112/32",
    #   "58.78.119.14/32",
    #   "211.60.226.136/32" ##시무집
    # ]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"] # 모든 대상
  }

  tags = {
    Name = "fanda-jenkins-sg"
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

# 3. Jenkins EC2 인스턴스
resource "aws_instance" "fanda-jenkins-instance" {

  ami           = data.aws_ami.ubuntu_2204.id
  instance_type = "t3.large"

  subnet_id                   = var.public_subnet_ids[1]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.fanda_jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.fanda_jenkins_profile.name

  root_block_device {
    volume_size           = 50 # GB, 기본 8GB -> 100GB로 확장
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # --- 위에서 작성한 완성된 User Data 스크립트로 교체 ---
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. 시스템 및 기본 패키지 설치
              sudo apt-get update -y
              sudo apt-get install -y fontconfig openjdk-17-jre git

              # 2. Docker 설치 및 설정
              sudo install -m 0755 -d /etc/apt/keyrings
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              sudo chmod a+r /etc/apt/keyrings/docker.asc
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

              # 3. Jenkins 설치
              sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
                https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
              echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
                https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install -y jenkins

              # 4. CI/CD 헬퍼 도구 설치
              sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              sudo curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
              sudo mv kustomize /usr/local/bin/

              # 5. 최종 설정 및 서비스 시작
              sudo usermod -aG docker jenkins
              sudo systemctl enable docker.service
              sudo systemctl start docker.service
              sudo systemctl enable jenkins
              # docker 그룹 권한 적용을 위해 jenkins 서비스를 재시작하는 것이 안전
              sudo systemctl restart jenkins
              EOF

  tags = {
    Name = "fanda-jenkins-instance"
  }
}