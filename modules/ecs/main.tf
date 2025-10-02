# Create ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.namespace}-cluster"
  tags = var.tags
}

# Create ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.namespace}-ecs_task_execution_role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecr_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.namespace}-ecs-tasks-sg"
  description = "Allow inbound traffic to ECS tasks"
  vpc_id      = var.vpc_id
  tags        = var.tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.namespace}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.namespace}-nginx"
      image     = "${var.ecr_repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# Create ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.namespace}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.ecs_subnet_ids
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "${var.namespace}-nginx"
    container_port   = 80
  }

  service_registries {
    registry_arn = aws_service_discovery_service.main.arn
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = var.cloud_map_namespace_name
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "main" {
  name = "${var.namespace}-servicediscovery"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_config {
    failure_threshold = 1
    type              = "HTTP"
  }
}
