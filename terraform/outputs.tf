output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_ca
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_group_role_arn" {
  value = module.eks.node_group_role_arn
}

output "karpenter_node_instance_profile" {
  value = module.karpenter.karpenter_node_instance_profile
}

output "argocd_initial_admin_password" {
  description = "Initial Argo CD admin password"
  value       = module.argocd.argocd_initial_admin_password
  sensitive   = true
}