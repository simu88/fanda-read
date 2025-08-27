## 헬름 차트를 이용한 alb-controller 설치
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"

  values = [
    yamlencode({
      # --- 기존 설정 ---
      region      = var.region
      vpcId       = var.vpc_id
      clusterName = var.cluster_name

      serviceAccount = {
        name   = "fanda-alb-sa"
        create = false
      }
    })
  ]

  # set {
  #   name  = "region"
  #   value = var.region
  # }

  # set {
  #   name  = "vpcId"
  #   value = var.vpc_id
  # }

  # set {
  #   name  = "clusterName"
  #   value = var.cluster_name
  # }

  # set {
  #   name  = "serviceAccount.name"
  #   value = "fanda-alb-sa"
  # }

  # set {
  #   name  = "serviceAccount.create"
  #   value = "false"
  # }

  ### 관련 IRSA가 모두 생성된 후에 설치되도록 설정
  depends_on = [
    aws_iam_role_policy_attachment.fanda_alb_policy_attach,
    aws_iam_role_policy_attachment.fanda_alb_ec2_describe_attach,
    aws_iam_role_policy_attachment.fanda_alb_sa_elb_full_access,
    kubernetes_service_account.fanda_alb_sa
  ]

}


## Application-Loadbalancer를 위한 Security Group
resource "aws_security_group" "fanda_alb_sg" {
  name        = "fanda-alb-sg"
  description = "Security Group for AWS Load Balancer Controller"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 공개 서비스가 아니라면 제한 가능
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fanda-alb-sg"
  }
}

