variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "users" {
  type    = list(string)
  default = ["fcg-games", "fcg-catalogs", "fcg-payments"]
}

variable "opensearch_domain" {
  type    = string
  default = "fcg-opensearch"
}

variable "opensearch_user_group_name" {
  type    = string
  default = "opensearch-user-group"
}

variable "github_user" {
  type = string
  default = "PauloBusch"
}

variable "github_repo" {
  type = string
  default = "fcg-games-microservice"
}