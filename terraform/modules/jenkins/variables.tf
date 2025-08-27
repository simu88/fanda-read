# vpc 값 받아오기
variable "vpc_id" {
  description = "Jenkins 리소스를 배포할 VPC의 ID"
  type = string
}

variable "public_subnet_ids" {
  description = "Jenkins 리소스를 배포할 서브넷"
  type = list(string)
}
