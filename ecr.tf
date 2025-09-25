resource "aws_ecr_repository" "fcg" {
  name = "fcg"
  image_scanning_configuration {
    scan_on_push = true
  }
}