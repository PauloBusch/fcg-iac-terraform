# OpenSearch user group
resource "aws_iam_group" "opensearch_user_group" {
  name = "opensearch-user-group"
}

resource "aws_iam_group_policy_attachment" "opensearch_access_group_policy" {
  group      = aws_iam_group.opensearch_user_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonOpenSearchServiceFullAccess"
}

# OpenSearch users
resource "aws_iam_user" "opensearch_users" {
  for_each      = { for ms in var.microservices_config : ms.key => ms }
  name     = each.value.opensearch_user
}

resource "aws_iam_user_group_membership" "opensearch_user_group_membership" {
  for_each = aws_iam_user.opensearch_users
  user     = each.value.name
  groups   = [aws_iam_group.opensearch_user_group.name]
}

resource "aws_iam_access_key" "opensearch_users_access_key" {
  for_each = aws_iam_user.opensearch_users
  user     = each.value.name
}

# CodeBuild role
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "codebuild.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# CodeBuild policies
resource "aws_iam_role_policy" "codebuild_s3_access" {
  name = "codebuild-s3-access"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = flatten([
          for ms in var.microservices_config : [
            aws_s3_bucket.s3_bucket[ms.key].arn,
            "${aws_s3_bucket.s3_bucket[ms.key].arn}/*"
          ]
        ])
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_logs_policy" {
  name = "codebuild-logs-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = flatten([
          for ms in var.microservices_config : [
            "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${ms.fcg_ci_project_name}",
            "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${ms.fcg_ci_project_name}:*"
          ]
        ])
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

# ECS role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SQS users
resource "aws_iam_user" "sqs_users" {
  for_each    = { for ms in var.microservices_sqs_config : ms.key => ms }
  name     = each.value.sqs_user
}

resource "aws_iam_access_key" "sqs_users_access_key" {
  for_each = aws_iam_user.sqs_users
  user     = each.value.name
}

resource "aws_iam_user_policy" "sqs_users_policy" {
  for_each = aws_iam_user.sqs_users
  name     = "sqs-access-policy"
  user     = each.value.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueues",
          "sqs:DeleteMessage"
        ],
        Resource = [
          aws_sqs_queue.fcg_sqs[each.key].arn,
          "${aws_sqs_queue.fcg_sqs[each.key].arn}/*"
        ]
      }
    ]
  })
}
