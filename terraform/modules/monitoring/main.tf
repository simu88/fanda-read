# 1. 네임스페이스 생성
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "fanda-monitoring"
  }
}


# 2. Prometheus 설치
resource "helm_release" "prometheus" {
  name          = "prometheus-stack"
  repository    = "https://prometheus-community.github.io/helm-charts"
  chart         = "kube-prometheus-stack"
  namespace     = kubernetes_namespace.monitoring.metadata[0].name
  version       = "76.4.0" # 검증된 최신 안정 버전
  recreate_pods = true

  values = [
    yamlencode({
      prometheus = {
        service = {
          type = "LoadBalancer"
          port : 80
          targetPort : 9090
          # [보안 권장] 특정 IP 대역에서만 접근을 허용합니다. (Grafana 설정과 동일하게 적용)
          # loadBalancerSourceRanges = [
          #   "118.218.200.33/32", # 사무실
          #   "58.78.119.14/32",   # 집
          #   "211.179.27.76/32",  # 카페
          #   "211.60.226.136/32"  # 정민 재택
          # ]

          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"             = "nlb",
            "service.beta.kubernetes.io/aws-load-balancer-scheme"           = "internet-facing",
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" = "/-/healthy",
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port" = "traffic-port"

          }


        }


        prometheusSpec = {
          retention = "7d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class_name
                accessModes      = ["ReadWriteOnce"]
                resources        = { requests = { storage = "20Gi" } }
              }
            }
          }
        }

        # EKS에서는 kubeControllerManager/kubeScheduler Rule 제거
        additionalPrometheusRulesMap = {
          "kubernetes-system-controller-manager" = null
          "kubernetes-system-scheduler"          = null
        }

      }

      kubeControllerManager = { enabled = false }
      kubeScheduler         = { enabled = false }

      alertmanager = {
        enabled = true
        service = {
          type       = "LoadBalancer"
          port       = 80
          targetPort = 9093
          # [보안 권장] Prometheus와 동일하게 접근 제어 설정
          # loadBalancerSourceRanges = [
          #   "118.218.200.33/32",
          #   "58.78.119.14/32",
          #   "211.179.27.76/32",
          #   "211.60.226.136/32" #정민
          # ]

          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"             = "nlb",
            "service.beta.kubernetes.io/aws-load-balancer-scheme"           = "internet-facing",
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path" = "/-/healthy",
            "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port" = "traffic-port"

          }
        }
        # Alertmanager Config
        config = {
          global = {
            resolve_timeout    = "5m"
            slack_api_url_file = "/etc/alertmanager/secrets/alertmanager-slack-secret/slack-url"
          }

          route = {
            receiver        = "slack-notifications"
            group_by        = ["job", "alertname"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "1h"
            routes = [
              {
                receiver = "null"
                matchers = ["alertname = Watchdog"]
              }
            ]
          }

          receivers = [
            {
              name = "slack-notifications"
              slack_configs = [
                {
                  channel       = "#모니터링-알람-eks"
                  send_resolved = true
                  title         = "{{ .CommonLabels.alertname }} - {{ .Status | toUpper }}"
                  text          = <<-EOT
              {{- range .Alerts }}
              *Summary:* {{ .Annotations.summary }}
              *Description:* {{ .Annotations.description }}
              *Details:*
              {{- range .Labels.SortedPairs }}
               - `{{ .Name }}` = `{{ .Value }}`
              {{- end }}
              {{- end }}
            EOT
                }
              ]
            },
            { name = "null" }
          ]
        }

        # Alertmanager Pod Spec
        alertmanagerSpec = {
          # chart 공식 지원 필드로 Secret 마운트
          secrets = ["alertmanager-slack-secret"]

        }
      }



      grafana = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}




data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "fanda_monitoring_bucket" {
  # 버킷 이름은 전역적으로 고유해야 하므로 계정 ID 등을 접미사로 추가하는 것을 권장합니다.
  bucket        = "fanda-monitoring-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "fanda-monitoring-bucket"
  }
}

# # S3 버킷에 Loki가 사용할 초기 폴더 구조 생성 (선택 사항)
# resource "aws_s3_object" "folders" {
#   for_each = {
#     "loki/chunks/" = "" # 청크(로그 데이터) 저장 경로
#     "loki/ruler/"  = "" # 알림 규칙 저장 경로
#     "loki/admin/"  = "" # 관리 메타데이터 저장
#   }

#   bucket  = aws_s3_bucket.fanda_monitoring_bucket.bucket
#   key     = each.key
#   content = each.value # 빈 객체를 생성하여 폴더처럼 보이게 함
# }



# Loki가 S3 버킷에 접근하는데 필요한 권한을 정의하는 IAM 정책
resource "aws_iam_policy" "loki_s3_policy" {
  name        = "loki-s3-access-policy"
  description = "Allows Loki to read/write/list/delete objects in its S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # {
      #   Effect = "Allow",
      #   Action = [
      #     "s3:PutObject",
      #     "s3:GetObject",
      #     "s3:DeleteObject"
      #   ],
      #   # Loki가 특정 경로 하위에만 객체를 생성/조회/삭제하도록 권한을 제한합니다.
      #   Resource = "${aws_s3_bucket.fanda_monitoring_bucket.arn}/loki/*"
      # },
      # {
      #   Effect   = "Allow",
      #   Action   = "s3:ListBucket",
      #   Resource = aws_s3_bucket.fanda_monitoring_bucket.arn,
      #   # Loki가 버킷 내 객체 목록을 조회할 수 있도록 허용합니다.
      #   Condition = {
      #     StringLike = {
      #       "s3:prefix" = ["loki/*"]
      #     }
      #   }
      # }
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "${aws_s3_bucket.fanda_monitoring_bucket.arn}",
          "${aws_s3_bucket.fanda_monitoring_bucket.arn}/*"
        ]
      }

    ]

  })
}


# Loki 파드의 서비스 어카운트가 위임받을 IAM 역할
resource "aws_iam_role" "loki_s3_role" {
  name = "loki-s3-role"

  # 이 역할을 위임받을 수 있는 주체(Principal)를 정의합니다.
  # EKS OIDC 공급자를 신뢰하고, 특정 네임스페이스와 서비스 어카운트 이름일 경우에만 허용합니다.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # "fanda-monitoring" 네임스페이스의 "loki" 서비스 어카운트만 이 역할을 위임받을 수 있습니다.
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:fanda-monitoring:loki"
          }
        }
      }
    ]
  })
}

# 생성한 IAM 역할에 S3 접근 정책을 연결합니다.
resource "aws_iam_role_policy_attachment" "loki_s3_attachment" {
  role       = aws_iam_role.loki_s3_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}




### Loki Helm 차트 배포- simpleScalable모드 
resource "helm_release" "loki" {
  name       = "loki"
  namespace  = "fanda-monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.38.0"

  recreate_pods   = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 300

  values = [
    yamlencode({
      # 1️⃣ 서비스 어카운트 + IRSA
      serviceAccount = {
        create = true
        name   = "loki"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.loki_s3_role.arn
        }
      }

      # 2️⃣ 배포 모드: SimpleScalable
      deploymentMode = "SimpleScalable"

      # 3️⃣ Loki 핵심 설정
      loki = {
        schemaConfig = {
          configs = [
            {
              from         = "2024-04-01"
              store        = "tsdb"
              object_store = "s3"
              schema       = "v13"
              index        = { prefix = "loki_index_", period = "24h" }
            }
          ]
        }

        storage_config = {
          aws = {
            region           = var.region
            bucketnames      = aws_s3_bucket.fanda_monitoring_bucket.bucket
            s3forcepathstyle = false
          }
        }

        storage = {
          type = "s3"
          bucketNames = {
            chunks = "${aws_s3_bucket.fanda_monitoring_bucket.bucket}/loki/chunks"
            ruler  = "${aws_s3_bucket.fanda_monitoring_bucket.bucket}/loki/ruler"
            admin  = "${aws_s3_bucket.fanda_monitoring_bucket.bucket}/loki/admin"
          }
          s3 = {
            region           = var.region
            signatureVersion = "v4"
            s3ForcePathStyle = false
            insecure         = false
            http_config      = {}
          }
        }

        pattern_ingester = { enabled = true }

        limits_config = {
          allow_structured_metadata = true
          volume_enabled            = true
          retention_period          = "672h" # 28일
        }

        querier = { max_concurrent = 4 }
      }

      # 4️⃣ 컴포넌트 복제 수
      backend = { replicas = 3 }
      read    = { replicas = 3 }
      write   = { replicas = 3 }

      # 5️⃣ minio 비활성화
      minio = { enabled = false }

      # 6️⃣ server readiness probe
      server = {
        http_listen_port          = 3100
        grpc_listen_port          = 9095
        http_server_read_timeout  = "600s"
        http_server_write_timeout = "600s"
        readinessProbe = {
          httpGet = {
            path = "/ready"
            port = 3100
          }
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 1
          failureThreshold    = 5
        }
      }

      # # 7️⃣ gateway 설정 (외부 Grafana 연결 가능)
      # gateway = {
      #   service = { type = "LoadBalancer" }
      # }
    })
  ]

  depends_on = [
    aws_s3_bucket.fanda_monitoring_bucket,
    aws_iam_role_policy_attachment.loki_s3_attachment
  ]
}





# # 3. Loki Helm 차트 배포 (S3 저장소 및 IRSA 설정 적용)
# resource "helm_release" "loki" {
#   name       = "loki"
#   namespace  = "fanda-monitoring"
#   repository = "https://grafana.github.io/helm-charts"
#   chart      = "loki"
#   version    = "6.5.1"

#   recreate_pods   = true
#   cleanup_on_fail = true
#   wait            = true
#   timeout         = 300 # 🔹 readiness 지연을 고려해 timeout 연장

#   values = [
#     yamlencode({
#       # 1️⃣ IRSA 적용 서비스 어카운트
#       serviceAccount = {
#         create = true
#         name   = "loki"
#         annotations = {
#           "eks.amazonaws.com/role-arn" = aws_iam_role.loki_s3_role.arn
#         }
#       }

#       # 2️⃣ multi Pod 모드 활성화
#       singleBinary = { enabled = false } # 🔹 수정: singleBinary → false

#       # write          = { replicas = 1, persistence = { enabled = false } }
#       # read           = { replicas = 1 }
#       # backend        = { replicas = 1 }
#       # gateway        = { replicas = 1 }
#       # compactor      = { replicas = 1 }
#       # distributor    = { replicas = 1 }
#       # queryScheduler = { replicas = 1 }

#       # 5️⃣ 캐시 관련
#       chunksCache = {
#         enabled = true
#         memcached = {
#           replicas = 1
#           resources = {
#             requests = { cpu = "200m", memory = "1Gi" }
#             limits   = { cpu = "500m", memory = "2Gi" }
#           }
#         }
#       }
#       resultsCache = { enabled = false }

#       # 6️⃣ Loki 핵심 설정 (S3 스토리지)
#       loki = {
#         deploymentMode = "distributed"
#         storage = {
#           type = "s3"
#           bucketNames = {
#             chunks = "loki/chunks"
#             ruler  = "loki/ruler"
#             admin  = "loki/admin"
#           }
#           s3 = {
#             bucketnames = aws_s3_bucket.fanda_monitoring_bucket.bucket
#             # region           = var.region
#             region           = "us-east-1"
#             endpoint         = "s3.us-east-1.amazonaws.com"
#             s3ForcePathStyle = false
#           }
#         }

#         schemaConfig = {
#           configs = [
#             {
#               from         = "2025-07-01"
#               store        = "tsdb"
#               object_store = "s3"
#               schema       = "v13"
#               index        = { prefix = "index_", period = "24h" }
#             }
#           ]
#         }

#         limits_config = {
#           allow_structured_metadata     = true
#           max_cache_freshness_per_query = "10m"
#           query_timeout                 = "300s"
#           reject_old_samples            = true
#           reject_old_samples_max_age    = "168h"
#           split_queries_by_interval     = "15m"
#           volume_enabled                = true
#         }

#         validation = {
#           allow_structured_metadata = true
#         }

#         memberlistConfig = {
#           join_members = ["loki-memberlist"]
#         }
#       }

#       # 7️⃣ readiness probe 수정 (503 방지) 🔹
#       server = {
#         http_listen_port          = 3100
#         grpc_listen_port          = 9095
#         http_server_read_timeout  = "600s"
#         http_server_write_timeout = "600s"
#         readinessProbe = {
#           httpGet = {
#             path = "/ready"
#             port = 3100
#           }
#           initialDelaySeconds = 30
#           periodSeconds       = 10
#           timeoutSeconds      = 1
#           failureThreshold    = 5
#         }
#       }
#     })
#   ]

#   depends_on = [
#     aws_s3_bucket.fanda_monitoring_bucket,
#     aws_iam_role_policy_attachment.loki_s3_attachment
#   ]
# }





# 4. Tempo 설치
resource "helm_release" "tempo" {
  name          = "tempo"
  repository    = "https://grafana.github.io/helm-charts"
  chart         = "tempo"
  namespace     = kubernetes_namespace.monitoring.metadata[0].name
  version       = "1.8.0"
  recreate_pods = true

  values = [
    yamlencode({
      persistence : {
        enabled : true
        storageClassName : var.storage_class_name
        accessModes : ["ReadWriteOnce"]
        size : "20Gi"
      }
      traces : { otlp : { grpc : { enabled : true }, http : { enabled : true } } }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}


# 5. OpenTelemetry Collector 설치
resource "helm_release" "opentelemetry_collector" {
  name          = "otel-collector"
  repository    = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart         = "opentelemetry-collector"
  namespace     = kubernetes_namespace.monitoring.metadata[0].name
  version       = "0.85.0"
  recreate_pods = true

  values = [
    yamlencode({
      # mode : "deployment"         # DaemonSet → Deployment 변경
      # replicas : 2                # 원하는 복제 수 설정
      mode : "daemonset"
      config : {
        receivers : {
          otlp : {
            protocols : {
              grpc : {}
              http : {}
            }
          }
        }

        processors : {
          batch : {}
        }


        exporters : {
          loki : { endpoint : "http://loki.fanda-monitoring.svc.cluster.local:3100/loki/api/v1/push" }
          otlphttp : { endpoint : "http://tempo.fanda-monitoring.svc.cluster.local:4318" }
          logging : { verbosity : "detailed" }
        }
        service : {
          pipelines : {
            traces : {
              receivers : ["otlp"]
              processors : ["batch"]
              exporters : ["logging", "otlphttp"]
            }
            metrics : {
              receivers : ["otlp"]
              processors : ["batch"]
              exporters : ["logging"]
            }
          }
        }
      }

      # resources : {
      #   limits : {
      #     cpu : "500m"
      #     memory : "1Gi"
      #   }
      #   requests : {
      #     cpu : "250m"
      #     memory : "512Mi"
      #   }
      # }


    })
  ]

  # helm_release.loki, 
  depends_on = [helm_release.tempo]
}


# 6. Grafana 설치
resource "helm_release" "grafana" {
  name          = "grafana"
  repository    = "https://grafana.github.io/helm-charts"
  chart         = "grafana"
  namespace     = kubernetes_namespace.monitoring.metadata[0].name
  version       = "7.3.11"
  recreate_pods = false

  values = [
    yamlencode({
      adminPassword : "Aws9@123" # [권장] 운영 환경에서는 Secret 사용
      serviceAccount : {
        create : false
        name : "cloudwatch-exporter"

      }
      datasources : {
        "datasources.yaml" : {
          apiVersion : 1
          datasources : [
            { name : "Prometheus", type : "prometheus", url : "http://prometheus-stack-prometheus.fanda-monitoring.svc.cluster.local:9090", access : "proxy", isDefault : true },
            { name : "Tempo", type : "tempo", url : "http://tempo.fanda-monitoring.svc.cluster.local:3100", access : "proxy" },
            { name : "Loki", type : "loki", url : "http://loki.fanda-monitoring.svc.cluster.local:3100", access : "proxy" },
            # CloudWatch Metrics
            {
              name : "CloudWatch",
              type : "cloudwatch",
              access : "proxy",
              jsonData : {
                authType : "arn_role", # IRSA로 AWS 권한 사용
                defaultRegion : "us-east-1"
              }
            }
          ]
        }
      }
      persistence : {
        enabled : true
        type : "pvc"
        storageClassName : var.storage_class_name
        accessModes : ["ReadWriteOnce"]
        size : "10Gi"
      }
      service : {
        type : "LoadBalancer"
        port : 80
        targetPort : 3000
        # loadBalancerSourceRanges : [
        #   "118.218.200.33/32", # 사무실
        #   "58.78.119.14/32",   # 집
        #   "211.179.27.76/32",  # 카페
        #   "211.60.226.136/32"  # 정민
        # ]
        annotations : {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb",
          "service.beta.kubernetes.io/aws-load-balancer-scheme" : "internet-facing"
        }
      }
    })
  ]
  # helm_release.loki, 
  depends_on = [helm_release.tempo, helm_release.prometheus]
}
