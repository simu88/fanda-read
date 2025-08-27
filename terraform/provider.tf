# 1. AWS 기본 프로바이더 (기존과 동일)
provider "aws" {
  region = var.region
}

# 2. EKS 클러스터가 생성된 후, 그 결과값을 사용하여 kubernetes 프로바이더를 설정
provider "kubernetes" {
  # "eks"라는 별칭(alias)을 부여하여 특정 클러스터를 가리키도록 함
  alias = "eks" 

  # module "eks"의 결과값을 직접 참조 (더 이상 dummy 값 필요 없음)
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)

  # 인증 토큰을 가져오는 동적 exec 블록 (이 방식이 최신 방식)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", module.eks.cluster_name, # 클러스터 이름도 직접 참조
      "--region",       var.region       # 또는 var.aws_region
    ]
  }
}

# 3. 위에서 설정한 kubernetes 프로바이더를 사용하여 helm 프로바이더를 설정
provider "helm" {
  # 동일한 "eks" 별칭을 부여
  alias = "eks"

  # kubernetes 프로바이더 설정을 그대로 가져와 사용
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region",       var.region
      ]
    }
  }
  
}






# # Kafka 프로바이더를 MSK Serverless에 맞게 설정합니다.
# provider "kafka" {
#   # 1. 부트스트랩 서버: MSK 모듈의 출력(output) 값에서 IAM용 엔드포인트를 가져옵니다.
#   bootstrap_servers = module.msk.bootstrap_servers

#   # 2. 인증 방식 설정: MSK Serverless는 SASL/IAM을 사용합니다.
#   //security_protocol = "SASL_SSL"
#   //sasl_mechanism    = "AWS_MSK_IAM"
# }



#---------------"카펜터 전용" 프로바이더 --------------------------
# 테라폼이 ECR Public Registry(us-east-1에 존재)접근을 위해 필요한 AWS 프로바이더 설정
# provider "aws" {
#   alias   = "use1"
#   region  = "us-east-1"
# }

# # 오직 카펜터 모듈에만 전달할 특별 설정입니다.
# # ECR Public 로그인 정보가 포함되어 있습니다.
# provider "helm" {
#   # (핵심) "karpenter_ecr" 이라는 새로운, 명확한 별칭을 부여합니다.
#   alias = "karpenter_ecr" 
  
#   # 위와 동일
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_ca)
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       args = [
#         "eks",
#         "get-token",
#         "--cluster-name", module.eks.cluster_name,
#         "--region",       "ap-northeast-1"
#       ]
#     }
#   }

  # # 이 프로바이더에만 ECR Public 로그인 설정을 추가합니다.
  # registry_login {
  #   address  = "public.ecr.aws"
  #   username = "AWS"
  #   password = data.aws_ecrpublic_authorization_token.default.password
  # }


# # ECR Public 토큰을 받아오는 데이터 소스 (변경 없음)
# data "aws_ecrpublic_authorization_token" "default" {
#   provider = aws.use1
# }




# data "aws_eks_cluster" "eks" {
#   name = var.eks_cluster_name
# }

# data "aws_eks_cluster_auth" "eks" {
#   name = var.eks_cluster_name
# }