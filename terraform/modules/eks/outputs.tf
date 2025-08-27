output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.fanda_eks.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.fanda_eks.endpoint
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.fanda_eks.arn
}

output "cluster_ca" {
  value = aws_eks_cluster.fanda_eks.certificate_authority[0].data
}

output "cluster_role_name" {
  description = "IAM role name for EKS"
  value       = aws_iam_role.fanda_eks_role.name
}

output "node_group_role_arn" {
  value = aws_iam_role.fanda_node_group_role.arn
}

output "node_group_security_group_id" {
   description = "The security group ID created by the EKS cluster for control plane communication."
  value       = aws_eks_cluster.fanda_eks.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  value       = aws_iam_openid_connect_provider.oidc.url
}

