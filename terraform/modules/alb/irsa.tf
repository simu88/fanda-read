# ALB용 IAM Role 생성
resource "aws_iam_role" "fanda_alb_role" {
  name = "fanda-alb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:fanda-alb-sa"
          }
        }
      }
    ]
  })
}


# ALB 설치할 때 필요한 IAM 정책 정의
data "http" "fanda_alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json"
}

# ALB 컨트롤러 전용 IAM 정책 생성 (공식 정책)
resource "aws_iam_policy" "fanda_alb_policy" {
  name   = "fanda-alb-policy"
  policy = data.http.fanda_alb_policy.response_body
}

# EC2 리소스 접근 허용 (서브넷, SG 등)
resource "aws_iam_policy" "fanda_alb_ec2_describe_policy" {
  name = "fanda_alb_ec2_describe_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

# 생성한 ALB Role과 공식ALB 정책 연결 (IAM Role과 연결)
resource "aws_iam_role_policy_attachment" "fanda_alb_policy_attach" {
  role       = aws_iam_role.fanda_alb_role.name
  policy_arn = aws_iam_policy.fanda_alb_policy.arn
}

# 생성한 ALB Role과 공식ALB 정책 연결 (IAM Role과 연결)
resource "aws_iam_role_policy_attachment" "fanda_alb_ec2_describe_attach" {
  role       = aws_iam_role.fanda_alb_role.name
  policy_arn = aws_iam_policy.fanda_alb_ec2_describe_policy.arn
}

# ELB FullAccess 정책 연결 (보조 정책 연결)
resource "aws_iam_role_policy_attachment" "fanda_alb_sa_elb_full_access" {
  role       = aws_iam_role.fanda_alb_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}





##--------------------- 생성한 ALB Role(관련 정책 연결 완료)을 SA에 연결------------------
# Kubernetes ServiceAccount 생성 (IAM Role과 연결)
resource "kubernetes_service_account" "fanda_alb_sa" {
  metadata {
    name      = "fanda-alb-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fanda_alb_role.arn
    }
  }
  depends_on = [
    aws_iam_role.fanda_alb_role,
    aws_iam_role_policy_attachment.fanda_alb_policy_attach,
    aws_iam_role_policy_attachment.fanda_alb_ec2_describe_attach,
    aws_iam_role_policy_attachment.fanda_alb_sa_elb_full_access,
  ]
}

#aws-auth ConfigMap에 SSO 관리 권한 등록
# resource "kubernetes_config_map" "aws_auth" {
#   provider = kubernetes.eks  
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = yamlencode([
#       {
#         rolearn  = "arn:aws:sts::886723286293:assumed-role/AWSReservedSSO_AdministratorAccess_be811d95ad9f0f4a/alex941@naver.com",
#         username = "admin",
#         groups   = ["system:masters"]
#       },
#       {
#         rolearn  = var.node_group_role_arn,
#         username = "system:node:{{EC2PrivateDNSName}}",
#         groups   = ["system:bootstrappers", "system:nodes"]
#       }
#     ])
#   }

#   depends_on = [
#     var.cluster_name,
#     var.node_group_role_arn
#   ]
# }
