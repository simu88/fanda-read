# resource "kubernetes_deployment_v1" "class_deploy" {
#   provider = kubernetes
#   metadata {
#     name = "class-deploy"
#     labels = {
#       app = "class"
#     }
#   }

#   spec {
#     replicas = 2
#     selector {
#       match_labels = {
#         app = "class"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "class"
#         }
#       }
#       spec {
#         container {
#           name  = "class-ctn"
#           image = "choicco89/aws9-eks-reg:v1"
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

# resource "kubernetes_service_v1" "class_service" {
#   provider = kubernetes
#   metadata {
#     name = "class-service"
#   }
#   spec {
#     selector = {
#       app = "class"
#     }
#     port {
#       protocol    = "TCP"
#       port        = 80
#       target_port = 8080
#     }
#   }
# }