# 1. ElastiCache 보안 그룹
resource "aws_security_group" "fanda_redis_sg" {
  name        = "fanda-redis-sg" # [수정] 이름 하드코딩
  description = "Allow Redis traffic from application security group"
  vpc_id      = var.vpc_id

  # Ingress Rule: 특정 애플리케이션 보안 그룹으로부터의 Redis(6379) 트래픽만 허용
  #   ingress {
  #     from_port       = 6379
  #     to_port         = 6379
  #     protocol        = "tcp"
  #     security_groups = [var.app_security_group_id] # 매우 중요
  #     description     = "Allow Redis traffic from Fanda App SG"
  #   }

  # Egress Rule: 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fanda-redis-sg" # [수정] 이름 하드코딩
  }
}

# 2. ElastiCache 서브넷 그룹
resource "aws_elasticache_subnet_group" "fanda_redis_subnet" {
  name       = "fanda-redis-subnet-group" # [수정] 이름 하드코딩
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "fanda-redis-subnet-group" # [수정] 이름 하드코딩
  }
}

# 3. ElastiCache IAM 인증을 위한 사용자 및 그룹
resource "aws_elasticache_user" "fanda_app_user" {
  user_id       = "fanda-app-user" # [수정] 이름 하드코딩
  user_name     = "fanda-app-user" # [수정] 이름 하드코딩
  engine        = "REDIS"
  access_string = "on ~* +@all"

  authentication_mode {
    type = "iam"
  }
}

resource "aws_elasticache_user_group" "fanda_app_user_group" {
  user_group_id = "fanda-app-user-group" # [수정] 이름 하드코딩
  engine        = "REDIS"
  user_ids = [
    "default", # 필수
  aws_elasticache_user.fanda_app_user.user_id]
}



# 4. ElastiCache 복제 그룹 (Redis 클러스터 본체)
resource "aws_elasticache_replication_group" "fanda_redis_cluster" {
  replication_group_id = "fanda-redis-cluster"

  # [오류 수정] 'replication_group_description' -> 'description' 으로 변경
  description = "Redis cluster for Fanda project"

  # --- 엔진 및 노드 사양 ---
  engine         = "redis"
  engine_version = "7.0"
  node_type      = "cache.t3.small"

  # --- 클러스터 규모 및 고가용성 ---
  num_cache_clusters         = 2
  automatic_failover_enabled = true

  # --- 네트워크 및 보안 ---
  subnet_group_name  = aws_elasticache_subnet_group.fanda_redis_subnet.name
  security_group_ids = [aws_security_group.fanda_redis_sg.id]
  user_group_ids     = [aws_elasticache_user_group.fanda_app_user_group.id]

  # --- 암호화 및 인증 ---
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true

  # --- 백업 및 유지보수 ---
  snapshot_retention_limit = 7
  snapshot_window          = "04:00-05:00"
  maintenance_window       = "sun:05:00-sun:06:00"
  apply_immediately        = false

  tags = {
    Name    = "fanda-redis-cluster"
    Project = "fanda"
  }
}