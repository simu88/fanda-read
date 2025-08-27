variable "region" {
  description = "AWS 리전"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "fanda-eks"
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN from EKS cluster"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC Provider URL from the EKS cluster"
  type        = string
}

# 클러스터에 설치된 스토리지 클래스 이름 (AWS EKS의 기본값은 'gp2' 또는 'gp3')
variable "storage_class_name" {
  description = "The storage class to use for PVCs."
  default     = "gp2"
}

