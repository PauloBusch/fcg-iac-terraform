resource "aws_ecs_cluster" "fcg_cluster" {
  name = var.ecs_cluster_name
}

resource "aws_ecs_task_definition" "fcg_ecs_task" {
  family                   = "fcg-ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode(
    concat(
      [
        for ms in var.microservices_config : {
          name      = ms.ecs_container_name
          image     = "${aws_ecr_repository.fcg_ecr[ms.key].repository_url}:latest"
          cpu       = 256
          memory    = 512
          essential = true
          portMappings = [
            {
              containerPort = ms.ecs_container_port
              hostPort      = ms.ecs_container_port
            }
          ]
          healthCheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost:${ms.ecs_container_port}/health || exit 1"]
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
                value = aws_iam_access_key.opensearch_users_access_key[ms.key].id
              },
              {
                name  = "ElasticSearchSettings__Secret"
                value = aws_iam_access_key.opensearch_users_access_key[ms.key].secret
              },
              {
                name  = "ElasticSearchSettings__Region"
                value = var.aws_region
              },
              {
                name  = "ASPNETCORE_HTTP_PORTS"
                value = tostring(ms.ecs_container_port)
              }
            ],
            (
              contains(keys(aws_sqs_queue.fcg_sqs), ms.key)
            ) ? [
              {
                name  = "AWS__SQS__PaymentsQueueUrl"
                value = aws_sqs_queue.fcg_sqs[ms.key].url
              },
              {
                name  = "AWS__SQS__Region"
                value = var.aws_region
              },
              {
                name  = "AWS__SQS__AccessKey"
                value = aws_iam_access_key.sqs_users_access_key[ms.key].id
              },
              {
                name  = "AWS__SQS__SecretKey"
                value = aws_iam_access_key.sqs_users_access_key[ms.key].secret
              }
            ] : []
          )
        }
      ],
      [
        {
          name      = "prometheus"
          image     = "prom/prometheus:latest"
          essential = false
          cpu       = 256
          memory    = 512
          portMappings = [
            {
              containerPort = 9090
              hostPort      = 9090
            }
          ]
          healthCheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost:9090/-/healthy || exit 1"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 10
          }
        },
        {
          name      = "grafana"
          image     = "grafana/grafana:latest"
          essential = false
          cpu       = 256
          memory    = 512
          portMappings = [
            {
              containerPort = 3000
              hostPort      = 3000
            }
          ]
          healthCheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
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
      ]
    )
  )
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.microservices_config
    content {
      from_port   = ingress.value.ecs_container_port
      to_port     = ingress.value.ecs_container_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
  task_definition = aws_ecs_task_definition.fcg_ecs_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = var.ecs_enable_remote_cmd

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
}