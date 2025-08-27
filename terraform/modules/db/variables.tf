# 사용할 AWS 리전을 변수로 선언합니다.
variable "aws_region" {
  description = "RDS가 생성된 리전"
  type        = string
  default     = "us-east-1" # 미국 동부 리전
}

# 프로젝트나 리소스를 식별하기 위한 공통 이름 태그를 변수로 선언합니다.
variable "project_name" {
  description = "A common name prefix for all resources."
  type        = string
  default     = "my-project"
}

# vpc 값 받아오기
variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

# 데이터베이스 마스터 비밀번호를 저장할 변수 (보안상 더 좋은 방법은 아래 4단계에서 설명)
variable "db_password" {
  description = "Password for the RDS master user."
  type        = string
  sensitive   = true # 이 변수 값을 터미널에 노출하지 않도록 설정
}

# variable "bastion_sg_id" {
#   description = "The Security Group ID of the existing Bastion Host."
#   type        = string
# }

# variable "eks_node_sg_id" {
#   description = "The Security Group ID of the existing Bastion Host."
#   type        = string
# }
