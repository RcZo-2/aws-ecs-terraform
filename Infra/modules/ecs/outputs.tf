output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "service_discovery_arn" {
  value = aws_service_discovery_service.main.arn
}

output "ecs_log_group_name" {
  value = aws_cloudwatch_log_group.ecs.name
}
