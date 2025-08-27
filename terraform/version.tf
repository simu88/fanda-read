terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.29.0"
      configuration_aliases = [kubernetes.eks]
    }
    aws = {
      source = "hashicorp/aws"
      version = "5.86.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.13.2"
    }
  }
}