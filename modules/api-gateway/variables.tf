variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "ecs_subnet_ids" {
  description = "List of IDs of ECS subnets"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "The ID of the ECS security group"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  type        = string
}

variable "aws_region" {
  description = "The AWS region"
  type        = string
}
