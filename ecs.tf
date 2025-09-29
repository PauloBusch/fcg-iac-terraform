resource "aws_ecs_cluster" "fcg_cluster" {
  name = var.ecs_cluster_name
}

resource "aws_ecs_task_definition" "fcg_task" {
  family                   = "fcg-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = var.ecs_container_name
      image     = aws_ecr_repository.fcg.repository_url
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      environment = [
        {
            name  = "ElasticSearchSettings__Endpoint"
            value = "https://${aws_opensearch_domain.fcg.endpoint}"
        },
        {
            name  = "ElasticSearchSettings__AccessKey"
            value = aws_iam_access_key.opensearch_users_access_key[var.opensearch_user].id
        },
        {
            name  = "ElasticSearchSettings__Secret"
            value = aws_iam_access_key.opensearch_users_access_key[var.opensearch_user].secret
        },
        {
            name  = "ElasticSearchSettings__Region"
            value = var.aws_region
        }
      ]
    },
    {
        name      = "grafana"
        image     = "grafana/grafana:latest"
        essential = false
        portMappings = [
            {
                containerPort = 3000
                hostPort      = 3000
            }
        ]
        environment = [
            {
                name  = "GF_SECURITY_ADMIN_PASSWORD"
                value = var.grafana_admin_password
            }
        ]
    },
    {
        name      = "prometheus"
        image     = "prom/prometheus:latest"
        essential = false
        portMappings = [
            {
                containerPort = 9090
                hostPort      = 9090
            }
        ]
        environment = []
    }
  ])
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "fcg_service" {
  name            = "fcg-service"
  cluster         = aws_ecs_cluster.fcg_cluster.id
  task_definition = aws_ecs_task_definition.fcg_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
}