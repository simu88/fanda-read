terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "..."
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}