
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# resource "kubernetes_manifest" "cert_hpa" {
#   manifest = yamldecode(file("${path.module}/certhpa.yml"))
# }

# resource "kubernetes_manifest" "class_hpa" {
#   manifest = yamldecode(file("${path.module}/classhpa.yml"))
# }

# resource "kubernetes_manifest" "home_hpa" {
#   manifest = yamldecode(file("${path.module}/homehpa.yml"))
# }

#hpa 를 위한 metric 서버 추가 설치 
# resource "helm_release" "metrics_server" {
#   name       = "metrics-server"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   namespace  = "kube-system"

#   set {
#     name  = "args"
#     value = "{--kubelet-insecure-tls=true,--kubelet-preferred-address-types=InternalIP}"
#   }
# }