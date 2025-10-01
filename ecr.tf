resource "aws_ecr_repository" "fcg_ecr" {
  name          = each.value.ecr_repository_name
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  force_delete  = true
  image_scanning_configuration {
    scan_on_push = true
  }
}