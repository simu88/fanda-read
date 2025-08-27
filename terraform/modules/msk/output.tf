output "msk_cluster_arn" {
  description = "The ARN of the MSK Serverless cluster."
  value       = aws_msk_serverless_cluster.fanda_msk_serverless.arn
}

# 부트스트랩 서버 정보는 data 소스를 통해 조회해야 합니다.
# output "bootstrap_brokers_sasl_iam" { ... }

# [수정 후]
output "bootstrap_servers" { # 출력 이름도 일관성 있게 변경하는 것을 권장
  description = "Bootstrap brokers for the MSK Serverless cluster (supports SASL/IAM)"
  value = local.bootstrap_server
}

output "topic_arn" {
  description = "The ARN of the MSK topic."
  value       = local.topic_arn
}

output "security_group_id" {
  value = aws_security_group.fanda_msk_sg.id
}