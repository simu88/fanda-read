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




resource "aws_s3_bucket" "fanda_monitoring_bucket" {
  # 버킷 이름은 전역적으로 고유해야 하므로 계정 ID 등을 접미사로 추가하는 것을 권장합니다.
  bucket = "fanda-monitoring-bucket"

  tags = {
    Name = "fanda-monitoring-bucket"
  }
}

# S3 버킷에 Loki가 사용할 초기 폴더 구조 생성 (선택 사항)
resource "aws_s3_object" "folders" {
  for_each = {
    "loki/chunks/" = "" # 청크(로그 데이터) 저장 경로
    "loki/ruler/"  = "" # 알림 규칙 저장 경로
    "loki/admin/"  = "" # 관리 메타데이터 저장
  }

  bucket  = aws_s3_bucket.fanda_monitoring_bucket.bucket
  key     = each.key
  content = each.value # 빈 객체를 생성하여 폴더처럼 보이게 함
}



# Loki가 S3 버킷에 접근하는데 필요한 권한을 정의하는 IAM 정책
resource "aws_iam_policy" "loki_s3_policy" {
  name        = "loki-s3-access-policy"
  description = "Allows Loki to read/write/list/delete objects in its S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        # Loki가 특정 경로 하위에만 객체를 생성/조회/삭제하도록 권한을 제한합니다.
        Resource = "${aws_s3_bucket.fanda_monitoring_bucket.arn}/loki/*"
      },
      {
        Effect   = "Allow",
        Action   = "s3:ListBucket",
        Resource = aws_s3_bucket.fanda_monitoring_bucket.arn,
        # Loki가 버킷 내 객체 목록을 조회할 수 있도록 허용합니다.
        Condition = {
          StringLike = {
            "s3:prefix" = ["loki/*"]
          }
        }
      }
    ]
  })
}


# # Loki 파드의 서비스 어카운트가 위임받을 IAM 역할
# resource "aws_iam_role" "loki_s3_role" {
#   name = "loki-s3-role"

#   # 이 역할을 위임받을 수 있는 주체(Principal)를 정의합니다.
#   # EKS OIDC 공급자를 신뢰하고, 특정 네임스페이스와 서비스 어카운트 이름일 경우에만 허용합니다.
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Federated = var.oidc_provider_arn
#         },
#         Action = "sts:AssumeRoleWithWebIdentity",
#         Condition = {
#           StringEquals = {
#             # "fanda-monitoring" 네임스페이스의 "loki" 서비스 어카운트만 이 역할을 위임받을 수 있습니다.
#             "${var.oidc_provider_url}:sub" = "system:serviceaccount:fanda-monitoring:loki"
#           }
#         }
#       }
#     ]
#   })
# }

# # 생성한 IAM 역할에 S3 접근 정책을 연결합니다.
# resource "aws_iam_role_policy_attachment" "loki_s3_attachment" {
#   role       = aws_iam_role.loki_s3_role.name
#   policy_arn = aws_iam_policy.loki_s3_policy.arn
# }

# # ===============================================================
# # 3. Loki Helm 차트 배포 (S3 저장소 및 IRSA 설정 적용)
# # ===============================================================
# # ===============================================================
# # 3. Loki Helm 차트 배포 (S3 저장소 및 IRSA 설정 적용)
# # ===============================================================
# resource "helm_release" "loki" {
#   name       = "loki"
#   namespace  = "fanda-monitoring"
#   repository = "https://grafana.github.io/helm-charts"
#   chart      = "loki"
#   version    = "6.5.1"

#   recreate_pods   = true
#   cleanup_on_fail = true
#   wait            = true
#   timeout         = 600

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

#       # 2️⃣ singleBinary 모드
#       singleBinary = {
#         replicas = 1
#         # PVC 제거 (S3에 모든 데이터를 저장)
#         persistence = {
#           enabled = false
#         }
#       }

#       # 3️⃣ 다른 컴포넌트 비활성화
#       write   = { replicas = 0 }
#       read    = { replicas = 0 }
#       backend = { replicas = 0 }

#       # 4️⃣ Loki 핵심 설정
#       loki = {
#         storage = {
#           type = "s3"
#           bucketNames = {
#             chunks = "loki/chunks"
#             ruler  = "loki/ruler"
#             admin  = "loki/admin"
#           }
#           s3 = {
#             bucketnames      = aws_s3_bucket.fanda_monitoring_bucket.bucket
#             region           = var.region
#             s3ForcePathStyle = true
#           }
#         }

#         schemaConfig = {
#           configs = [
#             {
#               from         = "2025-07-01"
#               store        = "boltdb-shipper"
#               object_store = "s3"
#               schema       = "v13"
#               index = {
#                 prefix = "index_"
#                 period = "24h"
#               }
#             }
#           ]
#         }
#       }

#       # 5️⃣ memcached 캐시 최소화 (메모리 과다 요청 방지)
#       chunksCache = {
#         enabled = true
#         memcached = {
#           replicas = 1
#           resources = {
#             requests = {
#               cpu    = "200m"
#               memory = "1Gi"
#             }
#             limits = {
#               cpu    = "500m"
#               memory = "2Gi"
#             }
#           }
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
      mode : "daemonset"
      config : {
        # [수정] Loki 서비스 이름이 단일 바이너리 모드에 맞게 변경되었을 수 있습니다.
        # 기본 서비스 이름인 'loki'를 사용하는 것이 더 안전합니다.
        exporters : {
          loki : { endpoint : "http://loki.fanda-monitoring.svc.cluster.local:3100/loki/api/v1/push" }
          otlphttp : { endpoint : "http://tempo.fanda-monitoring.svc.cluster.local:4318" }
          logging : { verbosity : "detailed" }
        }
        # ... (나머지 receivers, processors, service 설정은 그대로 유지) ...
      }
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
  recreate_pods = true

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
            { name : "Tempo", type : "tempo", url : "http://tempo.fanda-monitoring.svc.cluster.local:3200", access : "proxy" },
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
        loadBalancerSourceRanges : [
          "118.218.200.33/32", # 사무실
          "58.78.119.14/32",   # 집
          "211.179.27.76/32"   # 카페
        ]
        annotations : { "service.beta.kubernetes.io/aws-load-balancer-scheme" : "internet-facing" }
      }
    })
  ]
  # helm_release.loki, 
  depends_on = [helm_release.tempo, helm_release.prometheus]
}
