resource "aws_codebuild_project" "fcg_ci" {
  name          = var.fcg_ci_project_name
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30

  source {
    type      = "GITHUB"
    location  = "https://github.com/${var.github_user}/${var.github_repo}.git"
    buildspec = "ci-pipeline.yml"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "mcr.microsoft.com/dotnet/sdk:9.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.fcg.repository_url
    }

    environment_variable {
      name  = "ECR_REPOSITORY_DOMAIN"
      value = split("/", aws_ecr_repository.fcg.repository_url)[0]
    }

    environment_variable {
      name  = "ELASTICSEARCHSETTINGS_ENDPOINT"
      value = aws_opensearch_domain.fcg.endpoint
    }

    environment_variable {
      name  = "ELASTICSEARCHSETTINGS_ACCESSKEY"
      value = aws_iam_access_key.opensearch_users_access_key[var.opensearch_user].id
    }

    environment_variable {
      name  = "ELASTICSEARCHSETTINGS_SECRET"
      value = aws_iam_access_key.opensearch_users_access_key[var.opensearch_user].secret
    }
  }

  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifacts_bucket.bucket
    packaging = "ZIP"
    path = "artifacts/"
    artifact_identifier = "fcg-artifacts"
    encryption_disabled = false
  }

  depends_on = [
    aws_ecr_repository.fcg,
    aws_s3_bucket.artifacts_bucket
  ]
}
