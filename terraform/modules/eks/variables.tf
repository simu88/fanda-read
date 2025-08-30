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

