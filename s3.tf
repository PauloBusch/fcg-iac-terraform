resource "aws_s3_bucket" "artifacts_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment_name
  }
}
