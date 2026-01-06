variable "keycloak_config" {
  type = object({
    admin_user     = string
    admin_password = string
    ingress_port   = number
  })
  default = {
    admin_user        = "admin"
    admin_password    = "admin"
    ingress_port      = 8080
  }
}

variable "monitoring_config" {
  type = object({
    prometheus_port = number
    grafana_port    = number
    grafana_admin_user = string
    grafana_admin_password = string
  })
  default = {
    prometheus_port = 9090
    grafana_port    = 3000
    grafana_admin_user = "admin"
    grafana_admin_password = "admin"
  }
}

variable "microservices_config" {
  type = list(object({
    key                  = string
    opensearch_user      = string
    github_user          = string
    github_repository    = string
    container_port       = number
    service_port         = number
  }))
  default = [
    {
      key                  = "games"
      opensearch_user      = "fcg-games-opensearch-user"
      github_user          = "PauloBusch"
      github_repository    = "fcg-games-microservice"
      container_port       = 8080
      service_port         = 80
    },
    # {
    #   key                  = "payments"
    #   opensearch_user      = "fcg-payments-opensearch-user"
    #   github_user          = "M4theusVieir4"
    #   github_repository    = "fcg-payment-service"
    #   container_port       = 8081
    #   service_port         = 81
    # },
    # {
    #   key                  = "catalogs"
    #   opensearch_user      = "fcg-catalogs-opensearch-user"
    #   github_user          = "marceloalvees"
    #   github_repository    = "fcg-catalog-microservice"
    #   container_port       = 8082
    #   service_port         = 82
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
