variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "fanda-eks"
}

variable "eks_cluster_endpoint" {
  description = "EKS 클러스터 API 서버 endpoint"
  type        = string
  default     = "https://dummy"
}

variable "eks_cluster_ca" {
  description = "EKS 클러스터 인증서 (base64 encoded)"
  type        = string
  default     = "ZHVtbXk="  # base64로 'dummy'
}


# 데이터베이스 마스터 비밀번호를 저장할 변수 (보안상 더 좋은 방법은 아래 4단계에서 설명)
variable "db_password" {
  description = "Password for the RDS master user."
  type        = string
  sensitive   = true # 이 변수 값을 터미널에 노출하지 않도록 설정
}

variable "bastion_sg_id" {
  description = "The Security Group ID of the existing Bastion Host."
  type        = string
}

variable "eks_node_sg_id" {
  description = "The Security Group ID of the existing Bastion Host."
  type        = string
}
