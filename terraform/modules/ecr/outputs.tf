# 생성된 리포지토리 URI 출력
output "repository_url" {
  value = aws_ecr_repository.fanda_ecr_repo.repository_url
}