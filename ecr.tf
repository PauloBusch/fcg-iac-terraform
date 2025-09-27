resource "aws_ecr_repository" "fcg" {
  name = var.ecr_repository_name
  image_scanning_configuration {
    scan_on_push = true
  }
}