variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "fanda-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "cluster_iam_role_name" {
  description = "Name of the IAM role for EKS control plane"
  type        = string
  default     = "eks-cluster-example"
}


# vpc 값 받아오기
variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}



# # 루트 모듈로부터 전달받는다.
# variable "msk_cluster_arn" {
#   description = "The ARN of the MSK cluster for the Pod's IAM policy."
#   type        = string
#   default     = null 
# }

# variable "msk_bootstrap_servers" {
#   description = "The bootstrap servers for the MSK cluster."
#   type        = string
#   sensitive   = true
# }