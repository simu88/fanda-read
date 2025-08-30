variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "msk_cluster_arn" {
  type = string
}

variable "msk_bootstrap_servers" {
  type = string
}

variable "msk_topic_arn" {
  type = string
}
