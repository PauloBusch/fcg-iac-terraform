variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "opensearch_domain" {
  type    = string
  default = "fcg-opensearch"
}

variable "ecs_cluster_name" {
  type    = string
  default = "fcg-ecs-cluster"
}

variable "grafana_admin_password" {
  type    = string
  default = "Admin123$"
}
