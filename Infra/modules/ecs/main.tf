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

}
