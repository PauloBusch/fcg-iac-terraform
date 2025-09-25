resource "aws_codebuild_project" "docker_build" {
  name          = "fcg-docker-build"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30

  source {
    type      = "GITHUB"
    location  = "https://github.com/${var.github_user}/${var.github_repo}.git"
    buildspec = "ci-pipeline.yml"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.fcg.repository_url
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }
}
