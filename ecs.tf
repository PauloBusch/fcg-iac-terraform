resource "aws_ecs_cluster" "fcg_cluster" {
  name = var.ecs_cluster_name
}

# Microservices
resource "aws_ecs_task_definition" "fcg_ecs_task" {
  family                   = "fcg-ecs-task-${each.key}"
  for_each                 = { for ms in var.microservices_config : ms.key => ms }
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "fcg-ecs-${each.key}-container"
      image     = "${aws_ecr_repository.fcg_ecr[each.key].repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = each.value.ecs_container_port
          hostPort      = each.value.ecs_container_port
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${each.value.ecs_container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      environment = concat(
        [
          {
            name  = "ElasticSearchSettings__Endpoint"
            value = "https://${aws_opensearch_domain.fcg.endpoint}"
          },
          {
            name  = "ElasticSearchSettings__AccessKey"
            value = aws_iam_access_key.opensearch_users_access_key[each.key].id
          },
          {
            name  = "ElasticSearchSettings__Secret"
            value = aws_iam_access_key.opensearch_users_access_key[each.key].secret
          },
          {
            name  = "ElasticSearchSettings__Region"
            value = var.aws_region
          },
          {
            name  = "ASPNETCORE_HTTP_PORTS"
            value = tostring(each.value.ecs_container_port)
          }
        ],
        contains(keys(aws_sqs_queue.fcg_sqs), each.key) ? [
          {
            name  = "AWS__SQS__PaymentsQueueUrl"
            value = aws_sqs_queue.fcg_sqs[each.key].url
          },
          {
            name  = "AWS__SQS__Region"
            value = var.aws_region
          },
          {
            name  = "AWS__SQS__AccessKey"
            value = aws_iam_access_key.sqs_users_access_key[each.key].id
          },
          {
            name  = "AWS__SQS__SecretKey"
            value = aws_iam_access_key.sqs_users_access_key[each.key].secret
          }
        ] : []
      )
    }
  ])
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service-sg-${each.key}"
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  description = "Allow inbound traffic for ${each.key}"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = each.value.ecs_container_port
    to_port     = each.value.ecs_container_port
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
  name                    = "fcg-service-${each.key}"
  for_each                = { for ms in var.microservices_config : ms.key => ms }
  cluster                 = aws_ecs_cluster.fcg_cluster.id
  task_definition         = aws_ecs_task_definition.fcg_ecs_task[each.key].arn
  desired_count           = 1
  launch_type             = "FARGATE"
  enable_execute_command  = var.ecs_enable_remote_cmd

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_service_sg[each.key].id]
    assign_public_ip = true
  }
}

# Monitoring Services
locals {
  prometheus_container_port = 9090
  prometheus_image          = "prom/prometheus:latest"
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = local.prometheus_image
      essential = true
      portMappings = [
        {
          containerPort = local.prometheus_container_port
          hostPort      = local.prometheus_container_port
        }
      ]
      command = [
        "sh",
        "-c",
        "aws s3 cp s3://${var.config_bucket}/prometheus.yml /etc/prometheus/prometheus.yml && prometheus --config.file=/etc/prometheus/prometheus.yml"
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${local.prometheus_container_port}/-/healthy || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-sg"
  description = "Allow inbound traffic for Prometheus"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = local.prometheus_container_port
    to_port     = local.prometheus_container_port
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

resource "aws_ecs_service" "prometheus" {
  name                    = "prometheus"
  cluster                 = aws_ecs_cluster.fcg_cluster.id
  task_definition         = aws_ecs_task_definition.prometheus.arn
  desired_count           = 1
  launch_type             = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.prometheus_sg.id]
    assign_public_ip = true
  }
}

locals {
  grafana_container_port = 3000
  grafana_image          = "grafana/grafana:latest"
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = local.grafana_image
      essential = true
      portMappings = [
        {
          containerPort = local.grafana_container_port
          hostPort      = local.grafana_container_port
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${local.grafana_container_port}/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      environment = [
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_admin_password
        }
      ]
    }
  ])
}

resource "aws_security_group" "grafana_sg" {
  name        = "grafana-sg"
  description = "Allow inbound traffic for Grafana"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = local.grafana_container_port
    to_port     = local.grafana_container_port
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

resource "aws_ecs_service" "grafana" {
  name                    = "grafana"
  cluster                 = aws_ecs_cluster.fcg_cluster.id
  task_definition         = aws_ecs_task_definition.grafana.arn
  desired_count           = 1
  launch_type             = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.grafana_sg.id]
    assign_public_ip = true
  }
}
