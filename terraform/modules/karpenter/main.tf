resource "helm_release" "karpenter" {
  timeout          = 600
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.5.0" # 최신 안정 버전
  namespace        = var.namespace
  create_namespace = true

  # # 클러스터 이름 (v1.x에서는 settings.clusterName 사용)
  # set {
  #   name  = "settings.clusterName"
  #   value = var.cluster_name
  # }

  # # IRSA 설정
  # set {
  #   name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  #   value = aws_iam_role.fanda_karpenter_controller.arn
  # }

  # # AWS 기본 인스턴스 프로필
  # set {
  #   name  = "settings.aws.defaultInstanceProfile"
  #   value = aws_iam_instance_profile.fanda_karpenter_node_instance_profile.name
  # }

  # # AWS 리전 명시 (권장)
  # set {
  #   name  = "settings.aws.region"
  #   value = var.region
  # }

  values = [
    yamlencode({
      settings = {
        clusterName = var.cluster_name
        aws = {
          defaultInstanceProfile = aws_iam_instance_profile.fanda_karpenter_node_instance_profile.name
          region                 = var.region
        }
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.fanda_karpenter_controller.arn
        }
      }

      # =================== [추가] ===================
      # Karpenter 컨트롤러 파드가 코어 노드 그룹에만 배치되도록 설정

      # 1. 코어 노드 그룹의 Taint를 무시하도록 Toleration을 부여합니다.
      # tolerations = [
      #   {
      #     key      = "fanda-node-group-type"
      #     operator = "Equal"
      #     value    = "core-management"
      #     effect   = "NoSchedule"
      #   }
      # ]

      # # 2. 코어 노드 그룹에만 배치되도록 NodeAffinity를 설정합니다. (nodeSelector의 상위 호환)
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
      # ============================================
    })
  ]

}




# 카펜터가 생성할 노드들을 위한 전용 보안 그룹
resource "aws_security_group" "fanda_karpenter_node_sg" {
  name        = "fanda-karpenter-node-sg"
  description = "Security group for application nodes launched by Karpenter"
  vpc_id      = var.vpc_id


  # 1. 노드끼리 통신 허용 (자기 자신 SG)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all traffic from same SG"
  }

  # 2. EKS API 접근 허용
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
    description     = "Allow node access to EKS API server"
  }

  # 3. EKS 컨트롤 플레인 -> Kubelet 접근 허용 (추가할 규칙)
  #    이 규칙이 kubectl logs, exec 등의 기능을 위해 필수적입니다.
  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
    description     = "Allow EKS Control Plane to access Kubelet for logs/exec"
  }
  # ===================================================================


  # 4. 외부 아웃바운드 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }


  tags = {
    "Name" = "fanda-karpenter-node-sg"
    # 이렇게 하면 카펜터가 서브넷과 보안 그룹을 한 번에 찾을 수 있습니다.
    "karpenter.sh/discovery" = "fanda-eks"
  }
}

resource "aws_security_group_rule" "karpenter_node_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.eks_cluster_security_group_id
  source_security_group_id = aws_security_group.fanda_karpenter_node_sg.id
  description              = "Allow Karpenter nodes to access EKS API"
}


# Karpenter 노드를 EKS 클러스터에 등록   --->>>> 필수
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.fanda_karpenter_node_role.arn
  type          = "EC2_LINUX" # EC2 Linux 노드
}
