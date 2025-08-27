#====================================== MSK 토픽 생성을 위한 IRSA ==================================
# 1-1. AssumeRole 정책 (OIDC 기반)
data "aws_iam_policy_document" "eks_service_account_assume_role_topic" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:fanda-msk-topic:fanda-msk-topic-create-sa"]
    }
  }
}
# 1-2. 커스텀 IAM Role 생성
resource "aws_iam_role" "fanda_msk_topic_create_role" {
  name = "fanda-msk-topic-create-role"
  assume_role_policy = data.aws_iam_policy_document.eks_service_account_assume_role_topic.json
}
 
# 1-3. 커스텀 IAM 정책
resource "aws_iam_policy" "fanda_msk_topic_create_policy" {
  name        = "fanda-msk-topic-create-policy"
  description = "Allow creating MSK topics"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      
      # 클러스터 기본 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeClusterOperation"
        ],
        Resource = aws_msk_serverless_cluster.fanda_msk_serverless.arn
      },
      # 토픽 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          //"kafka-cluster:WriteData",
          //"kafka-cluster:AlterTopic",
          //"kafka-cluster:ReadData"
        ],
        Resource = local.topic_arn
      }
    ]
  })
}

# 1-4. IAM Role과 Policy 연결
resource "aws_iam_role_policy_attachment" "fanda_msk_topic_create_policy_attach" {
  role       = aws_iam_role.fanda_msk_topic_create_role.name
  policy_arn = aws_iam_policy.fanda_msk_topic_create_policy.arn
}


# 1-5. 토픽 생성용 IAM Role을 쿠버네티스 ServiceAccount에 연결 
resource "kubernetes_namespace" "fanda_msk_topic_ns" {
  metadata {
    name = "fanda-msk-topic" # 보통 var.namespace = "fanda-msk" 로 지정했겠죠?
  }
}

resource "kubernetes_service_account" "fanda_msk_topic_create_sa" {
  metadata {
    name      = "fanda-msk-topic-create-sa"
    namespace = kubernetes_namespace.fanda_msk_topic_ns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fanda_msk_topic_create_role.arn
    }
  }
}

# 1-6. MSK 주소 등의 식별을 위한 쿠버네티스 configmap 생성
resource "kubernetes_config_map" "fanda_msk_client_config" {
  metadata {
    name      = "fanda-msk-client-config"
    namespace = kubernetes_namespace.fanda_msk_topic_ns.metadata[0].name
  }

  data = {
    "client.properties" = <<EOT
    security.protocol=SASL_SSL
    sasl.mechanism=AWS_MSK_IAM
    sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
    sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
    EOT
  }
}

#================================ MSK <> Producer pod 통신을 위한 IRSA ============================

# 2-1. AssumeRole 정책 (OIDC 기반)
data "aws_iam_policy_document" "eks_service_account_assume_role_producer" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:fanda-msk-producer:fanda-msk-producer-sa"]
    }
  }
}

# 2-2. IAM Role for Producer
resource "aws_iam_role" "fanda_msk_producer_role" {
  name               = "fanda-msk-producer-role"
  assume_role_policy = data.aws_iam_policy_document.eks_service_account_assume_role_producer.json
}

# 2-3. IAM Policy for Producer (토픽 쓰기 권한)
resource "aws_iam_policy" "fanda_msk_producer_policy" {
  name        = "fanda-msk-producer-policy"
  description = "Allow producing data to MSK topics"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # 동적으로 MSK 클러스터 브로커 엔드포인트 조회 권한
      {
        Sid      = "GetBootstrapBrokers"
        Effect   = "Allow"
        Action   = [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster"
        ]
        Resource = aws_msk_serverless_cluster.fanda_msk_serverless.arn
      },
      # 클러스터 기본 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
          #"kafka-cluster:DescribeClusterOperation"
        ],
        Resource = aws_msk_serverless_cluster.fanda_msk_serverless.arn
      },
      # 토픽 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopic"
        ],
        Resource = local.topic_arn
      }
    ]
  })
}

# 2-4. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "fanda_msk_producer_policy_attach" {
  role       = aws_iam_role.fanda_msk_producer_role.name
  policy_arn = aws_iam_policy.fanda_msk_producer_policy.arn
}

# 2-5. Producer용 IAM Role을 쿠버네티스 ServiceAccount에 연결
resource "kubernetes_namespace" "fanda_msk_producer_ns" {
  metadata {
    name = "fanda-msk-producer"
  }
}

resource "kubernetes_service_account" "fanda_msk_producer_sa" {
  metadata {
    name      = "fanda-msk-producer-sa"
    namespace = kubernetes_namespace.fanda_msk_producer_ns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fanda_msk_producer_role.arn
    }
  }
}







#====================================== MSK <> Consumer Pod 통신을 위한 IRSA ==================================

# 3-1. AssumeRole 정책 (OIDC 기반)
data "aws_iam_policy_document" "eks_service_account_assume_role_consumer" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:fanda-msk-consumer:fanda-msk-consumer-sa"]
    }
  }
}

# 3-2. IAM Role for Consumer
resource "aws_iam_role" "fanda_msk_consumer_role" {
  name               = "fanda-msk-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.eks_service_account_assume_role_consumer.json
}

# 3-3. IAM Policy for Consumer (토픽 읽기 전용 권한)
resource "aws_iam_policy" "fanda_msk_consumer_policy" {
  name        = "fanda-msk-consumer-policy"
  description = "Allow consuming data from MSK topics"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # 동적으로 MSK 클러스터 브로커 엔드포인트 조회 권한
      {
        Sid      = "GetBootstrapBrokers"
        Effect   = "Allow"
        Action   = [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster"
        ]
        Resource = aws_msk_serverless_cluster.fanda_msk_serverless.arn
      },
      # 클러스터 기본 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
          //"kafka-cluster:DescribeClusterOperation"
        ],
        Resource = aws_msk_serverless_cluster.fanda_msk_serverless.arn
      },
      # 토픽 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeTopic"
          //"kafka-cluster:WriteData",
          //"kafka-cluster:AlterTopic",
          //"kafka-cluster:CreateTopic"
        ],
        Resource = local.topic_arn
      },
      
      # 소비자 그룹 권한
      {
        Effect   = "Allow",
        Action = [
          "kafka-cluster:DescribeGroup", # 그룹 상태 읽기 권한
          "kafka-cluster:AlterGroup"     # 그룹 참여/탈퇴 및 오프셋 커밋 권한
        ],
        Resource = local.group_arn
      }
    ]
  })
}

# 3-4. Attach Policy to Role
resource "aws_iam_role_policy_attachment" "fanda_msk_consumer_policy_attach" {
  role       = aws_iam_role.fanda_msk_consumer_role.name
  policy_arn = aws_iam_policy.fanda_msk_consumer_policy.arn
}

# 3-5. Consumer용 IAM Role을 쿠버네티스 ServiceAccount에 연결
resource "kubernetes_namespace" "fanda_msk_consumer_ns" {
  metadata {
    name = "fanda-msk-consumer" # 보통 var.namespace = "fanda-msk" 로 지정했겠죠?
  }
}
resource "kubernetes_service_account" "fanda_msk_consumer_sa" {
  metadata {
    name      = "fanda-msk-consumer-sa"
    namespace = kubernetes_namespace.fanda_msk_consumer_ns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fanda_msk_consumer_role.arn
    }
  }
}

