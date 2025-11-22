resource "aws_codepipeline" "fcg_pipeline" {
  name     = "fcg-pipeline-${each.key}"
  for_each = { for ms in var.microservices_config : ms.key => ms }
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.s3_bucket[each.key].bucket
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = "${each.value.github_user}/${each.value.github_repository}"
        BranchName       = "main"
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "BuildAndTest"
    action {
      name             = "BuildAndTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.fcg_ci[each.key].name
      }
    }
  }
  
  stage {
    name = "Deploy"
    action {
      name            = "DeployToEKS"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.fcg_ci[each.key].name
      }
    }
  }
}