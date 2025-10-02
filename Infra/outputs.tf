output "target_group_arn" {
  description = "The ARN of the API Gateway's target group"
  value       = module.api-gateway.target_group_arn
}
