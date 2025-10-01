variable "microservices_config" {
  type = list(object({
    key                  = string
    opensearch_user      = string
    github_user          = string
    github_repository    = string
    fcg_ci_project_name  = string
    ecr_repository_name  = string
    ecs_container_name   = string
    s3_bucket_name       = string
    ecs_container_port   = number
    ecs_host_port        = number
    sqs_user             = optional(string)
    sqs_queue_name       = optional(string)
  }))
  default = [
    {
      key                  = "games"
      opensearch_user      = "fcg-games-opensearch-user"
      github_user          = "PauloBusch"
      github_repository    = "fcg-games-microservice"
      fcg_ci_project_name  = "fcg-games-ci"
      ecr_repository_name  = "fcg-ecr-games-repository"
      ecs_container_name   = "fcg-ecs-games-container"
      s3_bucket_name       = "fcg-s3-games-bucket-6584"
      ecs_container_port   = 8080
      ecs_host_port        = 8080
    },
    {
      key                  = "payments"
      opensearch_user      = "fcg-payments-opensearch-user"
      github_user          = "M4theusVieir4"
      github_repository    = "fcg-payment-service"
      fcg_ci_project_name  = "fcg-payments-ci"
      ecr_repository_name  = "fcg-ecr-payments-repository"
      ecs_container_name   = "fcg-ecs-payments-container"
      s3_bucket_name       = "fcg-s3-payments-bucket-8865"
      sqs_user             = "fcg-payments-sqs-user"
      sqs_queue_name       = "fcg-payments-queue.fifo"
      ecs_container_port   = 8080
      ecs_host_port        = 8081
    },
    {
      key                  = "catalogs"
      opensearch_user      = "fcg-catalogs-opensearch-user"
      github_user          = "marceloalvees"
      github_repository    = "tech-challenge-net-phase-3"
      fcg_ci_project_name  = "fcg-catalogs-ci"
      ecr_repository_name  = "fcg-ecr-catalogs-repository"
      ecs_container_name   = "fcg-ecs-catalogs-container"
      s3_bucket_name       = "fcg-s3-catalogs-bucket"
      ecs_container_port   = 8080
      ecs_host_port        = 8082
    }
  ]
}