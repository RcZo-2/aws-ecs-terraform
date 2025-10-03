# Create an Application Load Balancer
resource "aws_lb" "alb" {
  name               = "ecs-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.ecs_subnet_ids
  security_groups    = [var.ecs_security_group_id]
}

# Create a target group for the ALB
resource "aws_lb_target_group" "ecs" {
  name        = "ecs-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

# Create a listener for the ALB
resource "aws_lb_listener" "ecs" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

# Create a security group for the VPC Link
resource "aws_security_group" "vpc_link" {
  name        = "vpc-link-sg"
  description = "Security group for the API Gateway VPC Link"
  vpc_id      = var.vpc_id
}

# Create a VPC Link for the API Gateway
resource "aws_apigatewayv2_vpc_link" "ecs" {
  name               = "ecs-alb-vpc-link"
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

# Create a CloudWatch log group for the API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api_gateway/${aws_apigatewayv2_api.http.name}"
  retention_in_days = 30
}

# Create a default stage for the API Gateway and enable access logging
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}
