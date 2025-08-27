# resource "kubernetes_deployment_v1" "home_deploy" {
#   provider = kubernetes
#   metadata {
#     name = "home-deploy"
#     labels = {
#       app = "home"
#     }
#   }

#   spec {
#     replicas = 2
#     selector {
#       match_labels = {
#         app = "home"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "home"
#         }
#       }
#       spec {
#         container {
#           name  = "home-ctn"
#           image = "choicco89/aws9-eks-notice:v1"
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

# resource "kubernetes_service_v1" "home_service" {
#   provider = kubernetes
#   metadata {
#     name = "home-service"
#   }
#   spec {
#     selector = {
#       app = "home"
#     }
#     port {
#       protocol    = "TCP"
#       port        = 80
#       target_port = 8080
#     }
#   }
# }