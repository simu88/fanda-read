output "rds_mysql_multi_az_endpoint" {
  description = "The connection endpoint for the Multi-AZ RDS for MySQL instance."
  value       = aws_db_instance.fanda_rds_instance.endpoint
}

output "rds_security_group_id" {
  description = "The security group ID for the RDS instance."
  value       = aws_security_group.fanda_rds_sg.id
}

output "docdb_security_group_id" {
  description = "The security group ID for the DocumentDB instance."
  value       = aws_security_group.fanda_docdb_sg.id
}