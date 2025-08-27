output "redis_primary_endpoint" {
  description = "The endpoint of the Redis primary node."
  value       = aws_elasticache_replication_group.fanda_redis_cluster.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "The endpoint of the Redis reader nodes for read scaling."
  value       = aws_elasticache_replication_group.fanda_redis_cluster.reader_endpoint_address
}

output "security_group_ids" {
  description = "The security group IDs associated with the Redis cluster."
  value       = aws_security_group.fanda_redis_sg.id
}