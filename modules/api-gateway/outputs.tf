output "target_group_arn" {
  description = "The ARN of the NLB target group"
  value       = aws_lb_target_group.ecs.arn
}

output "api_endpoint" {
  description = "The endpoint of the API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "vpc_link_security_group_id" {
  description = "The ID of the VPC Link security group"
  value       = aws_security_group.vpc_link.id
}
