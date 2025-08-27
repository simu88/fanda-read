# 생성된 vpc id 값 출력
output "vpc_id" {
  value = aws_vpc.eks_vpc.id
}

# 생성된 퍼블릭 서브넷 id 값 출력
output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

# 생성된 프라이빗 서브넷 id 값 출력
output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "bastion_security_group_id" {
  value = aws_security_group.fanda_bastion_sg.id
}
