variable "aws_region" {
  description = "The AWS region to deploy to."
  type        = string
  default     = "us-east-2"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "ecs_subnet_cidrs" {
  description = "List of CIDR blocks for ECS subnets"
  type        = list(string)
  default     = ["172.10.1.0/24", "172.10.2.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "ecr_repository_name" {
  description = "The name of the ECR repository"
  type        = string
  default     = "my-app"
}

variable "namespace" {
  description = "The namespace to use for all resources"
  type        = string
  default     = "my-namespace"
}

variable "cloud_map_namespace_name" {
  description = "The name of the Cloud Map namespace"
  type        = string
  default     = "my-cloud-map-namespace"
}
