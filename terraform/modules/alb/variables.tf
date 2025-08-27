variable "region" {
  description = "Name"
  type = string
}

variable "vpc_id" {
  description = "Name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "node_group_role_arn" {
  description = "EKS Node Group IAM Role ARN"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN passed from root module"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the OIDC provider for the EKS cluster"
  type        = string
}
