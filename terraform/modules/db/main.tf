# 1. RDS를 위한 보안 그룹 생성
# 이 보안 그룹은 오직 Bastion Host의 보안 그룹에서 오는 트래픽만 허용합니다.
resource "aws_security_group" "fanda_rds_sg" {
  name        = "fanda-rds-sg"
  description = "Allow MySQL traffic only from the existing Bastion host"
  vpc_id      = var.vpc_id # 기존에 생성한 EKS VPC ID를 사용합니다.

  # Ingress (인바운드 규칙):
  # Bastion 보안 그룹에서 오는 MySQL(3306) 트래픽만 허용하는 핵심 규칙입니다.
#   ingress {
#     description     = "MySQL from Bastion SG"
#     from_port       = 3306
#     to_port         = 3306
#     protocol        = "tcp"
#     security_groups = [var.bastion_sg_id] # 아래 variables.tf에서 정의할 변수입니다.
#   }

#   ingress {
#   description     = "MySQL from EKS NodeGroup"
#   from_port       = 3306
#   to_port         = 3306
#   protocol        = "tcp"
#   security_groups = [var.eks_node_sg_id] # 변수로 분리 가능
# }


  # Egress (아웃바운드 규칙): 모든 외부 통신을 허용합니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fanda-rds-sg"
  }
}


# 1-1. DB 서브넷 그룹 생성
#기존에 생성한 4개의 private 서브넷 중 3번째(index=2)와 4번째(index=3) 서브넷의 ID를 명시적으로 지정합니다.
resource "aws_db_subnet_group" "fanda_rds_sng" {
  name = "fanda-rds-sng"
  
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "fanda-rds-sng"
  }
}

# 1-2. RDS for MySQL DB 인스턴스 생성
resource "aws_db_instance" "fanda_rds_instance" {
  identifier           = "fanda-rds-instance"
  
  engine               = "mysql"
  engine_version       = "8.0.41" # RDS for MySQL 8.0 버전대 (예: 8.0.35, 8.0.36 등)
  instance_class       = "db.t3.large" # 다중 AZ는 t2/t3.micro를 지원하지 않습니다. medium 이상 사용.
  
  allocated_storage    = 20 # 스토리지 크기 (GB)
  db_name              = "fanda_rds"
  username             = "admin"
  
  # 자격 증명 직접 관리: 변수에서 비밀번호를 직접 받아옵니다.
  # 주의: 운영 환경에서는 보안을 위해 AWS Secrets Manager 사용을 강력히 권장합니다.
  password             = var.db_password 

  db_subnet_group_name = aws_db_subnet_group.fanda_rds_sng.name
  vpc_security_group_ids  = [aws_security_group.fanda_rds_sg.id]
  
  # 다중 AZ 배포를 활성화하여 고가용성을 확보합니다.
  # 장애 시 자동으로 다른 AZ의 예비 인스턴스로 전환됩니다.
  multi_az             = true 
  
  skip_final_snapshot  = true
}



#==============================================================================


# 2. DocumentDB를 위한 보안 그룹
# 이 보안 그룹은 EKS 클러스터의 "노드" 보안 그룹에서 오는 트래픽만 허용합니다.
# Bastion Host에서도 접속해야 하므로, Bastion 보안 그룹도 함께 허용합니다.
resource "aws_security_group" "fanda_docdb_sg" {
  name        = "fanda-docdb-sg"
  description = "Allow DocumentDB traffic from EKS Nodes and Bastion Host"
  vpc_id      = var.vpc_id

  # # Ingress (인바운드 규칙)
  # ingress {
  #   description     = "DocumentDB from EKS Nodes"
  #   from_port       = 27017
  #   to_port         = 27017
  #   protocol        = "tcp"
  #   # EKS 모듈에서 출력(output)한 노드 그룹의 보안 그룹 ID를 사용합니다.
  #   security_groups = [var.eks_node_sg_id] 
  # }
  # ingress {
  #   description     = "DocumentDB from Bastion Host"
  #   from_port       = 27017
  #   to_port         = 27017
  #   protocol        = "tcp"
  #   security_groups = [var.bastion_sg_id]
  # }

  # Egress (아웃바운드 규칙): 표준 설정
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fanda-docdb-sg"
  }
}


# 2-1. DocumentDB 서브넷 그룹 (Private-2, Private-3 사용)
resource "aws_docdb_subnet_group" "fanda_docdb_sng" {
  name       = "fanda-docdb-sng"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "fanda-docdb-sng"
  }
}


# 2-2. DocumentDB 클러스터
resource "aws_docdb_cluster" "fanda_docdb" {
  cluster_identifier      = "fanda-docdb-cluster"
  engine                  = "docdb"
  engine_version          = "4.0.0" # MongoDB 4.0 호환
  master_username         = "fanda_docdb_admin"
  master_password         = var.db_password
  
  db_subnet_group_name    = aws_docdb_subnet_group.fanda_docdb_sng.name
  vpc_security_group_ids  = [aws_security_group.fanda_docdb_sg.id]
  
  # 운영 환경에서는 백업 및 유지관리 설정을 더 상세하게 구성하는 것이 좋습니다.
  backup_retention_period = 7 # 7일간 백업 보관
  preferred_backup_window = "18:00-19:00" # UTC 기준, 한국 시간 새벽 3-4시
  skip_final_snapshot     = false # 운영 환경에서는 데이터를 보호하기 위해 false로 설정
  final_snapshot_identifier = "${var.project_name}-docdb-final-snapshot"
}

# 2-3. 클러스터 인스턴스 생성
resource "aws_docdb_cluster_instance" "fanda_docdb_instances" {
  count              = 2 # 고가용성을 위한 최소 구성
  identifier         = "fanda-docdb-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.fanda_docdb.id
  
  # 비용과 성능의 균형을 맞춘 Graviton2 인스턴스
  instance_class     = "db.r6g.large" 
}