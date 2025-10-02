output "target_group_arn" {
  description = "The ARN of the NLB target group"
  value       = aws_lb_target_group.ecs.arn
}


output "vpc_link_security_group_id" {
  description = "The ID of the VPC Link security group"
  value       = aws_security_group.vpc_link.id
}
