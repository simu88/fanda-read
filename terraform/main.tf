# 1. vpc 모듈 호출
module "vpc" {
  source = "./modules/vpc"

  msk_cluster_arn = module.msk.msk_cluster_arn
  topic_arn       = module.msk.topic_arn
}


# 2. db 모듈 호출
module "db" {
  source = "./modules/db"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = [
    module.vpc.private_subnet_ids[2],
    module.vpc.private_subnet_ids[3]
  ]
  db_password = var.db_password
  # bastion_sg_id     = var.bastion_sg_id
  # eks_node_sg_id = var.eks_node_sg_id

}

module "elasticcache" {
  source = "./modules/elasticcache"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = [
    module.vpc.private_subnet_ids[2],
    module.vpc.private_subnet_ids[3]
  ]
  # app_security_group_id = var.eks_node_sg_id
}

# 3. msk 모듈 호출
module "msk" {
  source = "./modules/msk"
  providers = {
    aws        = aws
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  vpc_id = module.vpc.vpc_id
  # MSK 엔드포인트를 생성할 Private Subnet 지정 (예: private-2, private-3)
  private_subnet_ids = [
    module.vpc.private_subnet_ids[0],
    module.vpc.private_subnet_ids[1]
  ]
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.ecr]
  # MSK에 접속을 허용할 소스 보안 그룹 목록
  # EKS 노드 그룹과 Lambda 함수의 보안 그룹을 전달
  //eks_node_sg_id = var.eks_node_sg_id
}

# # 3-1. msk 부트스트랩 서버 정보 조회
# data "aws_msk_bootstrap_brokers" "fanda_msk_serverless" {
#   cluster_arn = module.msk.msk_cluster_arn
# }


# 4. eks 모듈 호출
module "eks" {
  source             = "./modules/eks"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  # msk_cluster_arn=module.msk.msk_cluster_arn
  # msk_bootstrap_servers = data.aws_msk_bootstrap_brokers.fanda_msk_serverless.bootstrap_brokers_sasl_iam
}



# 이 방식은 순환 의존성을 완벽하게 방지합니다.
# 5-1. 규칙연결: EKS -> MSK 허용
resource "aws_security_group_rule" "eks_to_msk" {
  description              = "Allow EKS Nodes to access MSK"
  type                     = "ingress"
  from_port                = 9098 # MSK IAM 포트
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = module.msk.security_group_id            # 대상: MSK 보안 그룹
  source_security_group_id = module.eks.node_group_security_group_id # 소스: EKS 노드 보안 그룹
}



resource "aws_security_group_rule" "lambda_to_msk" {
  description              = "Allow Lambda to access MSK"
  type                     = "ingress"
  from_port                = 9098 # MSK IAM 포트
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = module.msk.security_group_id    # 대상: MSK 보안 그룹
  source_security_group_id = module.lambda.security_group_id # 소스: Lambda 보안 그룹
}

resource "aws_security_group_rule" "karpenter_to_msk" {
  description              = "Allow Karpenter to access MSK"
  type                     = "ingress"
  from_port                = 9098 # MSK IAM 포트
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = module.msk.security_group_id       # 대상: MSK 보안 그룹
  source_security_group_id = module.karpenter.security_group_id # 소스: Karpenter 보안 그룹
}

resource "aws_security_group_rule" "bastion_to_msk" {
  description              = "Allow Bastion to access MSK"
  type                     = "ingress"
  from_port                = 9098 # MSK IAM 포트
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = module.msk.security_group_id         # 대상: MSK 보안 그룹
  source_security_group_id = module.vpc.bastion_security_group_id # 소스: Bastion 보안 그룹
}

########### DB접근 ############

# 5-2. 규칙연결: EKS -> RDS DB허용
resource "aws_security_group_rule" "eks_to_rds_db" {
  description              = "Allow EKS Nodes to access RDS DB"
  type                     = "ingress"
  from_port                = 3306 # RDS DB 포트
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.db.rds_security_group_id         # 대상: DB 보안 그룹
  source_security_group_id = module.eks.node_group_security_group_id # 소스: EKS 노드 보안 그룹
}

# 5-3. 규칙연결: bastion -> RDS DB허용
resource "aws_security_group_rule" "bastion_to_rds_db" {
  description              = "Allow Bastion to access RDS DB"
  type                     = "ingress"
  from_port                = 3306 # RDS DB 포트
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.db.rds_security_group_id      # 대상: DB 보안 그룹
  source_security_group_id = module.vpc.bastion_security_group_id # 소스: Bastion 보안 그룹
}


resource "aws_security_group_rule" "karpenter_to_rds_db" {
  description              = "Allow Karpenter to access RDS DB"
  type                     = "ingress"
  from_port                = 3306 # RDS DB 포트
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.db.rds_security_group_id    # 대상: DB 보안 그룹
  source_security_group_id = module.karpenter.security_group_id # 소스: Karpenter 보안 그룹
}


###################################################33
# 5-4. 규칙연결: EKS -> DocumentDB 허용
resource "aws_security_group_rule" "eks_to_docdb" {
  description              = "Allow EKS Nodes to access DocumentDB"
  type                     = "ingress"
  from_port                = 27017 # DocumentDB 포트
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = module.db.docdb_security_group_id       # 대상: DB 보안 그룹
  source_security_group_id = module.eks.node_group_security_group_id # 소스: EKS 노드 보안 그룹
}

# 5-5. 규칙연결: bastion -> DocumentDB허용
resource "aws_security_group_rule" "bastion_to_docdb" {
  description              = "Allow Bastion to access DocumentDB"
  type                     = "ingress"
  from_port                = 27017 # DocumentDB 포트
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = module.db.docdb_security_group_id    # 대상: DB 보안 그룹
  source_security_group_id = module.vpc.bastion_security_group_id # 소스: Bastion 보안 그룹
}

# 5-5. 규칙연결: bastion -> DocumentDB허용
resource "aws_security_group_rule" "karpenter_to_docdb" {
  description              = "Allow Karpenter to access DocumentDB"
  type                     = "ingress"
  from_port                = 27017 # DocumentDB 포트
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = module.db.docdb_security_group_id  # 대상: DB 보안 그룹
  source_security_group_id = module.karpenter.security_group_id # 소스: Karpenter 보안 그룹
}



###################################################33
# 5-4. 규칙연결: EKS -> ElasticCache 허용
resource "aws_security_group_rule" "eks_to_ElasticCache" {
  description              = "Allow EKS Nodes to access ElasticCache"
  type                     = "ingress"
  from_port                = 6379 # ElasticCache 포트
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.elasticcache.security_group_ids  # 대상: DB 보안 그룹
  source_security_group_id = module.eks.node_group_security_group_id # 소스: EKS 노드 보안 그룹
}

# 5-5. 규칙연결: bastion -> ElasticCache 허용
resource "aws_security_group_rule" "bastion_to_ElasticCache" {
  description              = "Allow Bastion to access ElasticCache"
  type                     = "ingress"
  from_port                = 6379 # ElasticCache 포트
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.elasticcache.security_group_ids # 대상: DB 보안 그룹
  source_security_group_id = module.vpc.bastion_security_group_id   # 소스: Bastion 보안 그룹
}

# 5-5. 규칙연결: bastion -> ElasticCache허용
resource "aws_security_group_rule" "karpenter_to_elasticCache" {
  description              = "Allow Karpenter to access ElasticCache"
  type                     = "ingress"
  from_port                = 6379 # ElasticCache 포트
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.elasticcache.security_group_ids # 대상: DB 보안 그룹
  source_security_group_id = module.karpenter.security_group_id     # 소스: Karpenter 보안 그룹
}









module "cloudfront" {
  source = "./modules/cloudfront" # 이전 답변에서 만든 cloudfront.tf가 있는 모듈 경로


  # s3_bucket_id            = module.s3_banner.bucket_id
  # s3_bucket_arn           = module.s3_banner.bucket_arn
  # s3_regional_domain_name = module.s3_banner.bucket_regional_domain_name
  region = var.region

}

module "lambda" {
  source = "./modules/lambda"
  providers = {
    aws = aws
  }
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = [
    module.vpc.private_subnet_ids[0],
    module.vpc.private_subnet_ids[1]
  ]
  msk_cluster_arn       = module.msk.msk_cluster_arn
  msk_bootstrap_servers = module.msk.bootstrap_servers
  msk_topic_arn         = module.msk.topic_arn

}

module "argocd" {
  source = "./modules/argocd"
  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }
  depends_on = [null_resource.wait_for_cluster]

}

module "jenkins" {
  source            = "./modules/jenkins"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}



# ALB 모듈 호출
module "alb" {
  source       = "./modules/alb"
  region       = var.region
  vpc_id       = module.vpc.vpc_id
  cluster_name = module.eks.cluster_name

  node_group_role_arn = module.eks.node_group_role_arn
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  depends_on = [null_resource.wait_for_cluster]
}

module "ecr" {
  source = "./modules/ecr"
  providers = {
    aws = aws
  }

}

module "k8s" {
  source = "./modules/k8s"
  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }
  depends_on = [
    null_resource.wait_for_cluster,
    module.alb,
    //data.aws_eks_cluster.eks,
    //data.aws_eks_cluster_auth.eks
  ]
}


module "karpenter" {
  source                        = "./modules/karpenter"
  region                        = var.region
  vpc_id                        = module.vpc.vpc_id
  cluster_name                  = module.eks.cluster_name
  cluster_endpoint              = module.eks.cluster_endpoint
  oidc_provider_arn             = module.eks.oidc_provider_arn
  oidc_provider_url             = module.eks.oidc_provider_url
  eks_cluster_security_group_id = module.eks.node_group_security_group_id
  depends_on = [
    null_resource.wait_for_cluster,
    module.alb

  ]

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
    aws        = aws
  }
}

module "monitoring" {
  source            = "./modules/monitoring"
  region            = var.region
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
    aws        = aws
  }
  //depends_on = [module.k8s]
  depends_on = [
    module.karpenter,
    module.argocd
  ]
}


#------------의존성 처리 명령--------------

# 3. wait_for_cluster
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "aws eks wait cluster-active --name ${module.eks.cluster_name} --region ${var.region}"
  }
  depends_on = [module.eks]
}

