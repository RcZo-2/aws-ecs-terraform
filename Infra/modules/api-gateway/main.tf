# Create a Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "ecs-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.ecs_subnet_ids
}

# Create a target group for the NLB
resource "aws_lb_target_group" "ecs" {
  name        = "ecs-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

# Create a listener for the NLB
resource "aws_lb_listener" "ecs" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

# Create a security group for the VPC Link
resource "aws_security_group" "vpc_link" {
  name        = "vpc-link-sg"
  description = "Allow traffic from API Gateway to NLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
}

# Create a VPC Link for the API Gateway
resource "aws_apigatewayv2_vpc_link" "ecs" {
  name               = "ecs-vpc-link"
  subnet_ids         = var.ecs_subnet_ids
  security_group_ids = [aws_security_group.vpc_link.id]
}

# Create an API Gateway
resource "aws_apigatewayv2_api" "http" {
  name          = "ecs-api"
  protocol_type = "HTTP"
}

# Create a Cognito authorizer for the API Gateway
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [var.cognito_user_pool_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}
