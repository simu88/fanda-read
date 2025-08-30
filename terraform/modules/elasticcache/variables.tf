variable "vpc_id" {
  description = "ElastiCache와 애플리케이션이 위치한 VPC의 ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "ElastiCache 클러스터를 배포할 Private Subnet ID 목록"
  type        = list(string)

}

