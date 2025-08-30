output "security_group_id" {
  description = "The ID of the Jenkins security group."
  value       = aws_security_group.fanda_jenkins_sg.id
}