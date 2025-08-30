
# 1. MSK Serverless 클러스터를 위한 보안 그룹
resource "aws_security_group" "fanda_msk_sg" {
  name        = "fanda-msk-sg"
  description = "Allow Kafka traffic from EKS Nodes to MSK Serverless"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fanda-msk-sg"
  }
}


# 2. MSK Serverless 클러스터 생성
resource "aws_msk_serverless_cluster" "fanda_msk_serverless" {
  cluster_name = "fanda-msk-serverless"

  vpc_config {
    # MSK가 VPC 엔드포인트를 생성할 프라이빗 서브넷 목록
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.fanda_msk_sg.id]
  }

  client_authentication {
    # IAM 역할 기반 인증을 활성화합니다. Spring Boot Pod가 IAM Role을 사용해 접속합니다.
    sasl {
      iam {
        enabled = true
      }
    }
  }
}

# MSK 부트스트랩 서버 정보 조회
data "aws_msk_bootstrap_brokers" "fanda_msk_serverless" {
  cluster_arn = aws_msk_serverless_cluster.fanda_msk_serverless.arn
}

# (상위 모듈이나 같은 모듈 내에서)
locals {
  bootstrap_server = data.aws_msk_bootstrap_brokers.fanda_msk_serverless.bootstrap_brokers_sasl_iam
  topic_arn        = format("%s/*", replace(aws_msk_serverless_cluster.fanda_msk_serverless.arn, ":cluster/", ":topic/"))
  group_arn        = format("%s/*", replace(aws_msk_serverless_cluster.fanda_msk_serverless.arn, ":cluster/", ":group/"))


}


