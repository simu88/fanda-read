# vpc 전체 IP 주소 범위
variable "vpc_cidr" {
  description = "CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

# vpc 이름
variable "vpc_name" {
  description = "Name"
  type        = string
  default     = "eks-vpc"
}

# 사용할 가용 영역 리스트트
variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# 퍼블릿 서브넷에 할당할 CIDR 리스트
variable "public_subnet_cidrs" {
  description = "List of CIDRs for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19"]
}

# 프라이빗 서브넷에 할당할 CIDR 리스트
variable "private_subnet_cidrs" {
  description = "List of CIDRs for private subnets"
  type        = list(string)
  default     = ["10.0.64.0/19", "10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
}

variable "msk_cluster_arn" {
  description = "MSK Cluster ARN"
  type        = string
}

variable "topic_arn" {
  description = "MSK Topic ARN"
  type        = string
}