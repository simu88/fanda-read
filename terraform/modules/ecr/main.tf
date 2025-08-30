# ECR 리포지토리 생성
resource "aws_ecr_repository" "fanda_ecr_repo" {
  name = "fanda-ecr-repo" # 원하는 리포지토리 이름으로 변경

  image_tag_mutability = "MUTABLE" # 또는 "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# 리포지토리 정책 (선택 사항)
resource "aws_ecr_repository_policy" "fanda_ecr_repo_policy" {
  repository = aws_ecr_repository.fanda_ecr_repo.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPushPull",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}




#오래되거나 사용하지 않는 이미지를 자동으로 삭제하여 비용을 관리하기 위해 수명 주기 정책을 설정할 수 있습니다
# `aws_ecr_lifecycle_policy` 리소스를 사용합니다
resource "aws_ecr_lifecycle_policy" "fanda_ecr_repo_lifecycle_policy" {
  repository = aws_ecr_repository.fanda_ecr_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire images older than 30 days",
        selection = {
          tagStatus   = "any",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}




# ECR Repository: fanda-msk/topic
resource "aws_ecr_repository" "fanda_msk_topic" {
  name = "fanda-msk/topic"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_repository_policy" "fanda_msk_topic_policy" {
  repository = aws_ecr_repository.fanda_msk_topic.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPushPull",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "fanda_msk_topic_lifecycle" {
  repository = aws_ecr_repository.fanda_msk_topic.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire images older than 30 days",
        selection = {
          tagStatus   = "any",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}


# ECR Repository: fanda-msk/consumer
resource "aws_ecr_repository" "fanda_msk_consumer" {
  name = "fanda-msk/consumer"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_repository_policy" "fanda_msk_consumer_policy" {
  repository = aws_ecr_repository.fanda_msk_consumer.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPushPull",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "fanda_msk_consumer_lifecycle" {
  repository = aws_ecr_repository.fanda_msk_consumer.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire images older than 30 days",
        selection = {
          tagStatus   = "any",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
