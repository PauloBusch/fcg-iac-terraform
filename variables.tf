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

variable "ecs_enable_remote_cmd" {
  type    = bool
  default = true
}

variable "ecs_task_cpu" {
  type    = number
  default = 256
}

variable "ecs_task_memory" {
  type    = number
  default = 512
}

variable "config_bucket" {
  type    = string
  default = "fcg-s3-config"
}

variable "grafana_admin_password" {
  type    = string
  default = "Admin123$"
}
