terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source                 = "./modules/vpc"
  aws_region             = var.aws_region
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  ecs_subnet_cidrs       = var.ecs_subnet_cidrs
  availability_zones     = var.availability_zones
}

module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name
}

module "cognito" {
  source = "./modules/cognito"
}

module "api-gateway" {
  source                = "./modules/api-gateway"
  vpc_id                = module.vpc.vpc_id
  ecs_subnet_ids        = module.vpc.ecs_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  cognito_user_pool_id  = module.cognito.user_pool_id
  aws_region            = var.aws_region
}

module "ecs" {
  source                   = "./modules/ecs"
  vpc_id                   = module.vpc.vpc_id
  ecs_subnet_ids           = module.vpc.ecs_subnet_ids
  ecr_repository_url       = module.ecr.repository_url
  namespace                = var.namespace
  cloud_map_namespace_name = var.cloud_map_namespace_name
}

resource "aws_security_group_rule" "allow_vpc_link_to_ecs" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.api-gateway.vpc_link_security_group_id
  security_group_id        = module.ecs.ecs_security_group_id
}
