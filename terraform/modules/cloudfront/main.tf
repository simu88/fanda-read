data "aws_s3_bucket" "existing_banner_bucket" {
  bucket = "fanda-bucket-aws9-3" # <-- 여기에 실제 버킷 이름을 직접 입력합니다.
}


# --- 1. CloudFront Origin Access Control (OAC) 생성 ---
# OAI의 최신 버전으로, S3 Origin에 대한 접근을 제어합니다.
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${data.aws_s3_bucket.existing_banner_bucket.id}-oac"
  description                       = "Origin Access Control for ${data.aws_s3_bucket.existing_banner_bucket.arn}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- 2. CloudFront 배포(Distribution) 생성 ---
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = data.aws_s3_bucket.existing_banner_bucket.bucket_regional_domain_name # S3 버킷 리소스의 regional domain name을 사용
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = "S3-${data.aws_s3_bucket.existing_banner_bucket.id}"
    origin_path              = "/banners"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Distribution for ${data.aws_s3_bucket.existing_banner_bucket.id}"
  default_root_object = "index.html" # 기본 페이지가 있다면 지정

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${data.aws_s3_bucket.existing_banner_bucket.id}"

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized

    viewer_protocol_policy = "redirect-to-https"

    #
    # forwarded_values {
    #   query_string = false
    #   cookies {
    #     forward = "none"
    #   }
    # }

    # min_ttl                = 0
    # default_ttl            = 86400 # 1시간
    # max_ttl                = 604800 # 24시간
  }

  # 가격 분류 (필요에 따라 수정)
  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}



data "aws_iam_policy_document" "combined_policy" {
  ## banner는 모든 사용자에게 cloudfront를 통해 접근 가능  
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.existing_banner_bucket.arn}/banners/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }

  ## reports는 모든 사용자에게 public 접근 가능 (IAM계정 지정 가능)
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.existing_banner_bucket.arn}/reports/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]  # public 접근
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = data.aws_s3_bucket.existing_banner_bucket.id
  policy = data.aws_iam_policy_document.combined_policy.json
}
