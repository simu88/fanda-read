variable "region" {
  description = "The AWS region for the resources."
  type        = string
}

# variable "s3_bucket_id" {
#   description = "The ID (name) of the S3 bucket for CloudFront origin."
#   type        = string
#   # 예: "my-banner-bucket"
# }

# variable "s3_bucket_arn" {
#   description = "The ARN of the S3 bucket for CloudFront origin."
#   type        = string
# }

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    "Project"     = "Fanda"
    "ManagedBy"   = "Terraform"
  }
}