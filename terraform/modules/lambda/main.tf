# Lambda용 IAM Role 생성
resource "aws_iam_role" "fanda_s3_to_msk_lambda_role" {
  name = "fanda_s3_to_msk_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# MSK모듈에서 생성해 두었던 msk-producer IAM Policy 재활용
data "aws_iam_policy" "fanda_msk_producer_policy" {
  name = "fanda-msk-producer-policy"
}

# Lambda IAM Role에 producing policy 연결
resource "aws_iam_role_policy_attachment" "fanda_msk_producer_policy_attach" {
  role       = aws_iam_role.fanda_s3_to_msk_lambda_role.name
  policy_arn = data.aws_iam_policy.fanda_msk_producer_policy.arn
}


# Lambda IAM Role에 VPC 접근권한 추가(기본)
resource "aws_iam_role_policy_attachment" "fanda_lambda_cloudwatch" {
  role       = aws_iam_role.fanda_s3_to_msk_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda IAM Role에 Amazon CloudWatch Logs 기록 권한 추가(기본)
resource "aws_iam_role_policy_attachment" "fanda_lambda_basic" {
  role       = aws_iam_role.fanda_s3_to_msk_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Lambda 배포용 zip 자동 생성
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-function" # producer.py 등이 있는 폴더
  output_path = "${path.module}/lambda-deployment-package.zip"
}

# Lambda 보안그룹
resource "aws_security_group" "fanda_lambda_sg" {
  name        = "fanda_lambda_sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  # 아웃바운드 모든 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Lambda 함수 ---
resource "aws_lambda_function" "fanda_s3_to_msk_lambda" {
  function_name    = "fanda-s3-to-msk-lambda"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.fanda_s3_to_msk_lambda_role.arn
  handler          = "producer.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.fanda_lambda_sg.id]
  }

  # producer.py 환경 변수와 일치해야한다.
  environment {
    variables = {
      //MSK_BOOTSTRAP_SERVERS = var.msk_bootstrap_servers
      MSK_CLUSTER_ARN = var.msk_cluster_arn
      MSK_TOPIC       = "fanda-notifications" # 단일 토픽 이름
      CHANNELS        = "slack,email"         # 메시지 내부에 포함시킬 채널
    }
  }

  depends_on = [aws_iam_role_policy_attachment.fanda_msk_producer_policy_attach,
    aws_iam_role_policy_attachment.fanda_lambda_cloudwatch,
  aws_iam_role_policy_attachment.fanda_lambda_basic]
}




# # S3 초기 폴더 생성
# resource "aws_s3_object" "folders" {
#   for_each = {
#     "banners/"          = ""
#     "reports/positive/" = ""
#     "reports/negative/" = ""
#   }

#   bucket  = aws_s3_bucket.fanda_bucket_test.bucket
#   key     = each.key
#   content = each.value
# }


# 기존 S3 버킷 가져오기 (이미 만들어 놓았을 경우)
data "aws_s3_bucket" "fanda_bucket_existing" {
  bucket = "fanda-bucket-aws9-3"
}

# Lambda를 S3 이벤트에 연결
resource "aws_lambda_permission" "fanda_allow_s3_invoke" {
  statement_id  = "fanda-allow-s3-invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fanda_s3_to_msk_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.fanda_bucket_existing.arn
  # source_arn    = aws_s3_bucket.fanda_bucket_test.arn // 리소스로 정의한 s3 참조
}

# S3 Bucket Notification
resource "aws_s3_bucket_notification" "fanda_bucket_notification" {
  bucket = data.aws_s3_bucket.fanda_bucket_existing.id
  # bucket = aws_s3_bucket.fanda_bucket_test.id // 리소스로 정의한 s3 참조

  lambda_function {
    lambda_function_arn = aws_lambda_function.fanda_s3_to_msk_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/positive/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.fanda_s3_to_msk_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/negative/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.fanda_s3_to_msk_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/feedback/"
  }

  depends_on = [aws_lambda_permission.fanda_allow_s3_invoke]
}
