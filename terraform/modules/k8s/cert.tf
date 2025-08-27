# resource "kubernetes_deployment_v1" "cert_deploy" {
#   provider = kubernetes
#   metadata {
#     name = "cert-deploy"
#     labels = {
#       app = "cert"
#     }
#   }

#   spec {
#     replicas = 2
#     selector {
#       match_labels = {
#         app = "cert"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "cert"
#         }
#       }
#       spec {
#         # 이 노드들은 Karpenter의 'default' NodePool에 의해 생성됩니다.
#         affinity {
#           node_affinity {
#             required_during_scheduling_ignored_during_execution {
#               node_selector_term {
#                 match_expressions {
#                   key      = "fanda-compute-type"
#                   operator = "In"
#                   values   = ["application"]
#                 }
#               }
#             }
#           }
#         }
#         # ============================================
  


#         container {
#           name  = "cert-ctn"
#           image = "choicco89/aws9-eks-center:v1"
#           port {
#             container_port = 8080
#           }
#           resources {
#             limits = {
#               memory = "3600Mi"
#               cpu    = "900m"
#             }
#             requests = {
#               memory = "3000Mi"
#               cpu    = "800m"
#             }
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service_v1" "cert_service" {
#   provider = kubernetes
#   metadata {
#     name = "cert-service"
#   }
#   spec {
#     selector = {
#       app = "cert"
#     }
#     port {
#       protocol    = "TCP"
#       port        = 80
#       target_port = 8080
#     }
#   }
# }