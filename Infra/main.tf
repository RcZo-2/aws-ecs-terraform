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
  namespace                = var.namespace
  cloud_map_namespace_name = var.cloud_map_namespace_name
}

resource "aws_security_group_rule" "allow_alb_to_ecs" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = module.ecs.ecs_security_group_id
  self              = true
}
