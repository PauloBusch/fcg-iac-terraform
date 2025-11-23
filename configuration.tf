variable "microservices_config" {
  type = list(object({
    key                  = string
    opensearch_user      = string
    github_user          = string
    github_repository    = string
  }))
  default = [
    {
      key                  = "games"
      opensearch_user      = "fcg-games-opensearch-user"
      github_user          = "PauloBusch"
      github_repository    = "fcg-games-microservice"
    },
    # {
    #   key                  = "payments"
    #   opensearch_user      = "fcg-payments-opensearch-user"
    #   github_user          = "M4theusVieir4"
    #   github_repository    = "fcg-payment-service"
    # },
    # {
    #   key                  = "catalogs"
    #   opensearch_user      = "fcg-catalogs-opensearch-user"
    #   github_user          = "marceloalvees"
    #   github_repository    = "fcg-catalog-microservice"
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
