# vpc 값 받아오기
variable "vpc_id" {
  type = string
}
# 배포할 private_subnets 루트로부터 받기
variable "private_subnet_ids" {
  type = list(string)
}

# # eks security group 받아오기
# variable "eks_node_sg_id" {
#   description = "The Security Group ID of the existing Bastion Host."
#   type        = string
# }


variable "namespace" {
  description = "Namespace for the MSK topic creation"
  type        = string
  default     = "fanda-msk"
}


variable "kafka_cli_image" {
  description = "Docker image for Kafka CLI"
  type        = string
  default     = "746491138596.dkr.ecr.ap-northeast-1.amazonaws.com/fanda-ecr-repo:latest"
}

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the OIDC provider"
  type        = string
}