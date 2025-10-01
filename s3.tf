resource "aws_s3_bucket" "s3_bucket" {
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  bucket        = each.value.s3_bucket_name
  force_destroy = true

  tags = {
    Name        = each.value.s3_bucket_name
  }
}
