variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "environment_name" {
  type    = string
  default = "Production"
}

variable "users" {
  type    = list(string)
  default = ["fcg-games", "fcg-catalogs", "fcg-payments"]
}

variable "opensearch_domain" {
  type    = string
  default = "fcg-opensearch"
}

# TODO: Refactor - One per microsservice
variable "opensearch_user" {
  type    = string
  default = "fcg-games"
}

variable "github_user" {
  type = string
  default = "PauloBusch"
}

variable "github_repo" {
  type = string
  default = "fcg-games-microservice"
}

variable "fcg_ci_project_name" {
  type    = string
  default = "fcg-games-ci"
}

variable "ecr_repository_name" {
  type    = string
  default = "fcg-ecr-games-repository"
}

variable "s3_bucket_name" {
  type    = string
  default = "fcg-s3-games-bucket-545"
}