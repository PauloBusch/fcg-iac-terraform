resource "aws_ecr_repository" "fcg_ecr" {
  name          = "fcg-ecr-${each.key}-repository"
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  force_delete  = true
  image_scanning_configuration {
    scan_on_push = true
  }
}