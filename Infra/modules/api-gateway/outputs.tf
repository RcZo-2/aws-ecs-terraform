output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = aws_lb_target_group.ecs.arn
}

output "vpc_link_security_group_id" {
  description = "The ID of the VPC Link security group"
  value       = aws_security_group.vpc_link.id
}

output "api_gateway_id" {
  description = "The ID of the API Gateway"
  value       = aws_apigatewayv2_api.http.id
}

output "alb_listener_arn" {
  description = "The ARN of the ALB listener"
  value       = aws_lb_listener.ecs.arn
}

output "vpc_link_id" {
  description = "The ID of the VPC Link"
  value       = aws_apigatewayv2_vpc_link.ecs.id
}

output "authorizer_id" {
  description = "The ID of the Cognito authorizer"
  value       = aws_apigatewayv2_authorizer.cognito.id
}
