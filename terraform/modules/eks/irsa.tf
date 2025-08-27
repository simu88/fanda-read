# EKS OIDC 공급자 생성
# 이 모듈이 EKS 클러스터를 직접 생성하므로, 그 결과물을 사용해 OIDC 공급자를 만듭니다.
resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.fanda_eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd2e0f4"]
}


# #==============================================================================
# # 1. Bedrock 접근을 위한 IRSA (IAM Role for Service Account) 설정
# # 1-1. Bedrock 접근 권한을 정의하는 IAM 정책
# resource "aws_iam_policy" "fanda_policy_bedrock_s3" {
#   name        = "fanda-policy-bedrock-s3"
#   description = "Allows invoking Bedrock models"
#   policy = jsonencode({
#     Version   = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = "bedrock:InvokeModel"
#       Resource = "*" # 실제 운영 환경에서는 특정 모델 ARN으로 제한하는 것이 더 안전합니다.
#     },
#     {
#         Effect   = "Allow"
#         Action   = ["s3:PutObject", "s3:GetObject"] # 파일 업로드 및 확인용
#         Resource = "arn:aws:s3:::your-s3-bucket-name/*" # 실제 S3 버킷 ARN으로 반드시 제한!
#       },
#     {
#         Effect = "Allow",
#         Action = [
#           "kafka-cluster:Connect",
#           "kafka-cluster:WriteData",
#           "kafka-cluster:DescribeTopic",
#           "kafka-cluster:CreateTopic" # 필요에 따라 토픽 생성 권한도 추가
#         ],
#         # MSK Serverless 모듈이 출력한 클러스터 ARN을 직접 참조
#         Resource = var.msk_cluster_arn
#       }
#     ]
#   })



# }

# # 1-2. Kubernetes 서비스 계정(SA)이 사용할 IAM 역할
# resource "aws_iam_role" "fanda_role_bedrock_s3" {
#   name = "fanda-role-bedrock-s3"
#   assume_role_policy = jsonencode({
#     Version   = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = {
#         # 위에서 생성한 OIDC 공급자의 ARN을 직접 참조합니다.
#         Federated = aws_iam_openid_connect_provider.oidc.arn
#       }
#       Action    = "sts:AssumeRoleWithWebIdentity"
#       Condition = {
#         StringEquals = {
#           # 위에서 생성한 OIDC 공급자의 URL을 직접 참조하여 조건을 설정합니다.
#           "${aws_iam_openid_connect_provider.oidc.url}:sub" = "system:serviceaccount:fanda-be-marketing:fanda-sa-bedrock-s3"
#         }
#       }
#     }]
#   })


# }

# # 1-3. 생성한 정책을 역할에 연결
# resource "aws_iam_role_policy_attachment" "fanda_attach_bedrock_s3" {
#   role       = aws_iam_role.fanda_role_bedrock_s3.name
#   policy_arn = aws_iam_policy.fanda_policy_bedrock_s3.arn
# }



# #------------------------------쿠버네티스 리소스 생성-----------------------------------

# # 1-4. 서비스 계정이 위치할 네임스페이스 생성
# resource "kubernetes_namespace" "fanda_be_marketing" {
#   metadata {
#     name = "fanda-be-marketing"
#   }

#   # eks 클러스터 접근 권한 생긴 후에 리소스 생성되도록 설정
#   depends_on = [
#     aws_eks_access_policy_association.sso_admin_policy
#   ]
# }

# # 1-5. IAM 역할과 연결될 서비스 계정 생성
# resource "kubernetes_service_account" "fanda_sa_bedrock_s3" {
#   # 네임스페이스가 먼저 생성되도록 명시적인 의존성을 추가합니다.

#   metadata {
#     name      = "fanda-sa-bedrocks-s3"
#     namespace = kubernetes_namespace.fanda_be_marketing.metadata[0].name

#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.fanda_role_bedrock_s3.arn
#     }
#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.fanda_attach_bedrock_s3
#   ]

# }

# #------------------------------config map 생성-----------------------------------

# resource "kubernetes_config_map" "fanda_be_marketing_config" {
#   metadata {
#     name      = "fanda-be-marketing-config"
#     namespace = kubernetes_namespace.fanda_be_marketing.metadata[0].name
#   }
#   data = {
#     # "MSK_BOOTSTRAP_SERVERS" 라는 키(Key)에
#     # 2단계에서 조회한 IAM 인증용 주소 문자열(Value)을 할당한다.
#      "MSK_BOOTSTRAP_SERVERS" = var.msk_bootstrap_servers

#     # 다른 설정들도 추가할 수 있다.
#     #"RDS_ENDPOINT" = module.db.rds_instance_endpoint 
#     #"S3_BUCKET"    = "fanda-report-bucket"
#   }

# }



