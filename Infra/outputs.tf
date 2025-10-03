output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = module.ecs.ecs_cluster_id
}

output "ecs_subnet_ids" {
  description = "List of IDs of ECS subnets"
  value       = module.vpc.ecs_subnet_ids
}

output "ecs_security_group_id" {
  description = "The ID of the ECS security group"
  value       = module.ecs.ecs_security_group_id
}

output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = module.api-gateway.target_group_arn
}

output "service_discovery_arn" {
  description = "The ARN of the service discovery service"
  value       = module.ecs.service_discovery_arn
}

output "api_gateway_id" {
  description = "The ID of the API Gateway"
  value       = module.api-gateway.api_gateway_id
}

output "alb_listener_arn" {
  description = "The ARN of the ALB listener"
  value       = module.api-gateway.alb_listener_arn
}

output "vpc_link_id" {
  description = "The ID of the VPC link"
  value       = module.api-gateway.vpc_link_id
}

output "authorizer_id" {
  description = "The ID of the Cognito authorizer"
  value       = module.api-gateway.authorizer_id
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = module.ecs.ecs_task_execution_role_arn
}

output "ecs_log_group_name" {
  description = "The name of the ECS log group"
  value       = module.ecs.ecs_log_group_name
}
