variable "vpc_id" {
  description = "ElastiCache와 애플리케이션이 위치한 VPC의 ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "ElastiCache 클러스터를 배포할 Private Subnet ID 목록"
  type        = list(string)
  # 예: ["subnet-0a1b2c3d4e5f6", "subnet-0f6e5d4c3b2a1"]
}

