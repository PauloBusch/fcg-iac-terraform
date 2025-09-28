resource "aws_opensearch_domain" "fcg" {
  domain_name           = var.opensearch_domain
  engine_version        = "OpenSearch_1.3"
  cluster_config {
    instance_type = "t3.small.search"
    instance_count = 1
    zone_awareness_enabled = false
  }
  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }
  access_policies = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
    "Principal": {
      "AWS": ${jsonencode([for user in aws_iam_user.opensearch_users : user.arn])}
      },
      "Action": "es:*",
      "Resource": "*"
    }
  ]
}
POLICY
}

data "aws_iam_user" "opensearch_users" {
  for_each = toset(var.users)
  user_name = each.key

  depends_on = [
    aws_iam_user.opensearch_users
  ]
}