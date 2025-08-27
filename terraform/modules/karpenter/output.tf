output "karpenter_controller_role_arn" {
  value = aws_iam_role.fanda_karpenter_controller.arn
}

output "karpenter_node_instance_profile" {
  value = aws_iam_instance_profile.fanda_karpenter_node_instance_profile.name
}

output "security_group_id" {
  description = "The ID of the Karpenter node's security group."
  value       = aws_security_group.fanda_karpenter_node_sg.id
}