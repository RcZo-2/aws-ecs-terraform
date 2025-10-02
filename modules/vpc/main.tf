resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.10.0.0/16"
}

locals {
  public_subnets = {
    for i, cidr in var.public_subnet_cidrs :
    cidr => {
      cidr = cidr
      az   = var.availability_zones[i]
    }
  }
  private_subnets = {
    for i, cidr in var.private_subnet_cidrs :
    cidr => {
      cidr = cidr
      az   = var.availability_zones[i]
    }
  }
  ecs_subnets = {
    for i, cidr in var.ecs_subnet_cidrs :
    cidr => {
      cidr = cidr
      az   = var.availability_zones[i]
    }
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${each.key}"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${each.key}"
  }
}

# Create ECS subnets
resource "aws_subnet" "ecs" {
  for_each                = local.ecs_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "ecs-subnet-${each.key}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Create Private Route Table
resource "aws_route_table" "private" {
  for_each = local.private_subnets
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "private-route-table-${each.key}"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Create ECS Route Table
resource "aws_route_table" "ecs" {
  for_each = local.ecs_subnets
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "ecs-route-table-${each.key}"
  }
}

# Associate ECS Subnets with ECS Route Table
resource "aws_route_table_association" "ecs" {
  for_each       = aws_subnet.ecs
  subnet_id      = each.value.id
  route_table_id = aws_route_table.ecs[each.key].id
}

# Create VPC Endpoints for ECR
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids        = [for s in aws_subnet.ecs : s.id]
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids        = [for s in aws_subnet.ecs : s.id]
  security_group_ids = [aws_security_group.vpc_endpoint.id]
}

# Create VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.ecs : rt.id]
}

# Security group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint" {
  name   = "vpc-endpoint-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
