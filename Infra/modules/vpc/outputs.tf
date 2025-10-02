output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = [for s in aws_subnet.private : s.id]
}

output "ecs_subnet_ids" {
  description = "List of IDs of ECS subnets"
  value       = [for s in aws_subnet.ecs : s.id]
}
