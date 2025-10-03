variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "ecs_subnet_ids" {
  description = "List of IDs of ECS subnets"
  type        = list(string)
}

variable "namespace" {
  description = "The namespace to use for all resources"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

variable "cloud_map_namespace_name" {
  description = "The name of the Cloud Map namespace"
  type        = string
}
