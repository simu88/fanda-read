# # --- 1. Lambda 함수 코드 준비 ---
# # Lambda 코드를 별도의 파일로 관리합니다.
# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   source_file = "${path.module}/lambda_function.py"
#   output_path = "${path.module}/lambda_function.zip"
# }

# # --- 2. Lambda 실행을 위한 IAM 역할 및 정책 ---
# data "aws_iam_policy_document" "lambda_assume_role" {
#   statement {
#     actions = ["sts:AssumeRole"]
#     principals {
#       type        = "Service"
#       identifiers = ["lambda.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "lambda_invalidation_role" {
#   name               = "lambda-cloudfront-invalidation-role"
#   assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
# }

# # Lambda가 CloudWatch Logs에 로그를 쓰고 CloudFront 무효화를 생성할 권한
# data "aws_iam_policy_document" "lambda_invalidation_policy" {
#   statement {
#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents"
#     ]
#     resources = ["arn:aws:logs:*:*:*"]
#   }

#   statement {
#     actions   = ["cloudfront:CreateInvalidation"]
#     resources = [aws_cloudfront_distribution.s3_distribution.arn]
#   }
# }

# resource "aws_iam_policy" "lambda_invalidation_policy" {
#   name   = "lambda-cloudfront-invalidation-policy"
#   policy = data.aws_iam_policy_document.lambda_invalidation_policy.json
# }

# resource "aws_iam_role_policy_attachment" "lambda_invalidation_attach" {
#   role       = aws_iam_role.lambda_invalidation_role.name
#   policy_arn = aws_iam_policy.lambda_invalidation_policy.arn
# }

# # --- 3. Lambda 함수 생성 ---
# resource "aws_lambda_function" "cloudfront_invalidator" {
#   function_name    = "CloudFrontCacheInvalidator"
#   filename         = data.archive_file.lambda_zip.output_path
#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
#   handler = "lambda_function.lambda_handler"
#   runtime = "python3.9"
#   role    = aws_iam_role.lambda_invalidation_role.arn

#   environment {
#     variables = {
#       CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.s3_distribution.id
#     }
#   }

#   tags = var.tags
# }

# # --- 4. Lambda 함수를 S3 이벤트에 연결하는 권한 ---
# resource "aws_lambda_permission" "allow_s3" {
#   statement_id  = "AllowS3ToInvokeLambda"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.cloudfront_invalidator.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = "arn:aws:s3:::${var.s3_bucket_id}"
# }

# # --- 5. S3 버킷 알림 설정 ---
# # S3 버킷 리소스에 직접 알림 구성을 추가해야 합니다.
# # (주의: 이 리소스는 기존 S3 버킷 리소스에 구성을 추가하는 방식입니다)
# resource "aws_s3_bucket_notification" "bucket_notification" {
#   bucket = var.s3_bucket_id

#   lambda_function {
#     lambda_function_arn = aws_lambda_function.cloudfront_invalidator.arn
#     events              = ["s3:ObjectCreated:*"] # 모든 객체 생성 이벤트에 트리거
#     # filter_prefix       = "banners/" # 'banners/' 폴더에만 트리거하고 싶다면 이 줄의 주석을 해제
#   }

#   # 이 depends_on은 S3가 존재하지 않는 Lambda를 호출하려 시도하는 것을 방지합니다.
#   depends_on = [aws_lambda_permission.allow_s3]
# }