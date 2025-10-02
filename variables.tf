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
  type    = string
  default = "1024" 
  # default = "2048"
}

variable "ecs_task_memory" {
  type    = string
  default = "2048"
  # default = "4096"
}

variable "grafana_admin_password" {
  type    = string
  default = "Admin123$"
}
