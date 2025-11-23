resource "aws_codebuild_project" "fcg_ci" {
  name          = "fcg-ci-${each.key}"
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30

  source {
    type      = "GITHUB"
    location  = "https://github.com/${each.value.github_user}/${each.value.github_repository}.git"
    buildspec = "ci-pipeline.yml"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.fcg_ecr[each.key].repository_url
    }

    environment_variable {
      name  = "ECR_REPOSITORY_DOMAIN"
      value = split("/", aws_ecr_repository.fcg_ecr[each.key].repository_url)[0]
    }
  }

  artifacts {
    type = "S3"
    location = aws_s3_bucket.s3_bucket[each.key].bucket
    packaging = "ZIP"
    path = "artifacts/"
    artifact_identifier = "fcg-artifacts"
    encryption_disabled = false
  }

  depends_on = [
    aws_ecr_repository.fcg_ecr,
    aws_s3_bucket.s3_bucket
  ]
}
