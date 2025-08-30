resource "kubernetes_ingress_v1" "fanda_ingress" {
  provider = kubernetes

  metadata {
    name      = "fanda-ingress"
    namespace = "default"
    annotations = {
      # "kubernetes.io/ingress.class"              = "alb"  -> 예전에 많이 사용한 방식
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"  = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      #아직 인증서 발급 안댐 "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:ap-northeast-2:886723286293:certificate/f858aced-e1d3-4653-a9c6-3c547f2300bc"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/home"
          path_type = "Prefix"

          backend {
            service {
              name = "cert-service"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/shop"
          path_type = "Prefix"

          backend {
            service {
              name = "class-service"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/login"
          path_type = "Prefix"

          backend {
            service {
              name = "home-service"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/grafana"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}


