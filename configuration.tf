variable "microservices_config" {
  type = list(object({
    key                  = string
    opensearch_user      = string
    github_user          = string
    github_repository    = string
    ecs_container_port   = number
  }))
  default = [
    {
      key                  = "games"
      opensearch_user      = "fcg-games-opensearch-user"
      github_user          = "PauloBusch"
      github_repository    = "fcg-games-microservice"
      ecs_container_port   = 8080
    },
    # {
    #   key                  = "payments"
    #   opensearch_user      = "fcg-payments-opensearch-user"
    #   github_user          = "M4theusVieir4"
    #   github_repository    = "fcg-payment-service"
    #   ecs_container_port   = 8081
    # },
    # {
    #   key                  = "catalogs"
    #   opensearch_user      = "fcg-catalogs-opensearch-user"
    #   github_user          = "marceloalvees"
    #   github_repository    = "tech-challenge-net-phase-3"
    #   ecs_container_port   = 8082
    # }
  ]
}

variable "microservices_sqs_config" {
  type = list(object({
    key           = string
    sqs_user      = string
    sqs_queue_name = string
  }))
  default = [
    {
      key            = "payments"
      sqs_user       = "fcg-payments-sqs-user"
      sqs_queue_name = "fcg-payments-queue.fifo"
    }
  ]
}
