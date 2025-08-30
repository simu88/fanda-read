variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Karpenter will operate"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  type = string
}

variable "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN from EKS cluster"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the OIDC provider for the EKS cluster"
  type        = string
}


variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "fanda-karpenter"
}

