output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_security_group_id" {
  description = "The ID of the ECS security group"
  value       = aws_security_group.ecs_tasks.id
}

output "service_discovery_arn" {
  description = "The ARN of the service discovery service"
  value       = aws_service_discovery_service.main.arn
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_log_group_name" {
  description = "The name of the ECS log group"
  value       = aws_cloudwatch_log_group.ecs.name
}
