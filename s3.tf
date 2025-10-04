resource "aws_s3_bucket" "s3_bucket" {
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  bucket        = "fcg-s3-${each.key}-bucket"
  force_destroy = true

  tags = {
    Name        = "fcg-s3-${each.key}-bucket"
  }
}

resource "aws_s3_bucket" "config_bucket" {
  bucket        = var.config_bucket
  force_destroy = true

  tags = {
    Name = var.config_bucket
  }
}

data "template_file" "prometheus_config" {
  template = file("${path.module}/prometheus.yml.tmpl")
  vars = {
    region       = var.aws_region
    cluster_name = var.ecs_cluster_name
  }
}

resource "aws_s3_object" "prometheus_config" {
  key    = "prometheus.yml"
  bucket = aws_s3_bucket.config_bucket.bucket
  content = data.template_file.prometheus_config.rendered
}