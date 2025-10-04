resource "aws_s3_bucket" "s3_bucket" {
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  bucket        = "fcg-s3-${each.key}-bucket"
  force_destroy = true

  tags = {
    Name        = "fcg-s3-${each.key}-bucket"
  }
}