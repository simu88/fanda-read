
output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.fanda_s3_to_msk_lambda.function_name
}


output "security_group_id" {
    description = "The ID of the Lambda function's security group."
    value       = aws_security_group.fanda_lambda_sg.id
}

# # 생성된 버킷의 이름을 출력합니다. (terraform apply 후 확인 가능)
# output "s3_bucket_name" {
#   description = "The name of the created S3 bucket."
#   value       = aws_s3_bucket.fanda_bucket_test.id
# }

# # 생성된 버킷의 ARN(Amazon Resource Name)을 출력합니다.
# output "s3_bucket_arn" {
#   description = "The ARN of the created S3 bucket."
#   value       = aws_s3_bucket.fanda_bucket_test.arn
# }
