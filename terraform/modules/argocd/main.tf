# 파일 경로: modules/argocd/main.tf

resource "helm_release" "fanda_argocd" {
  timeout    = 600
  name       = "fanda-argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.3.2"

  namespace        = "fanda-cicd"
  create_namespace = true

  values = [
    yamlencode({
      # --- 기본 설정 ---
      fullnameOverride = "fanda-argocd"

      # =================== [핵심 수정] ===================
      # 'global' 설정을 사용하여 모든 컴포넌트에 공통 규칙을 한 번에 적용합니다.
      # 이렇게 하면 코드가 간결해지고 실수를 방지할 수 있습니다.
      global = {
        # 1. Tolerations: 코어 노드 그룹의 Taint를 용인하도록 설정
        tolerations = [
          {
            key      = "fanda-node-group-type"
            operator = "Equal"
            value    = "core-management"
            effect   = "NoSchedule" # [수정] "NO_SCHEDULE" -> "NoSchedule"
          }
        ]
        # 2. Affinity: 코어 노드 그룹에만 배치되도록 강제
        # affinity = {
        #   nodeAffinity = {
        #     requiredDuringSchedulingIgnoredDuringExecution = {
        #       nodeSelectorTerms = [
        #         {
        #           matchExpressions = [
        #             {
        #               key      = "fanda-node-group-type"
        #               operator = "In"
        #               values   = ["core-management"]
        #             }
        #           ]
        #         }
        #       ]
        #     }
        #   }
        # }
      }

      # =================== [운영 권장 사항] ===================
      # 고가용성(HA) 및 리소스 설정을 추가하여 운영 안정성을 높입니다.

      controller = {
        replicas = 2 # 단일 장애점 제거
      }

      server = {
        replicas = 2 # 단일 장애점 제거
        # [수정] 서비스 설정을 여기에 통합합니다.
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"     = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-internal" = "false"
          }
        }
      }

      repoServer = {
        replicas = 2 # 단일 장애점 제거
      }

      redis-ha = {
        enabled  = true # 프로덕션 환경에서는 Redis HA 모드 활성화 권장
        replicas = 2
        haproxy = {
          replicas = 2 # HAProxy replicas
        }
        # tolerations = [
        #   {
        #     key      = "fanda-node-group-type"
        #     operator = "Equal"
        #     value    = "core-management"
        #     effect   = "NoSchedule"
        #   }
        # ]
      }

      # ApplicationSet과 Notifications는 Argo CD의 강력한 기능입니다.
      # global 설정이 자동으로 적용되므로 활성화만 하면 됩니다.
      applicationSet = {
        enabled = true
      }
      notifications = {
        enabled = true
      }
    })
  ]
}


