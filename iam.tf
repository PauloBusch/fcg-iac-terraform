# OpenSearch user group
resource "aws_iam_group" "opensearch_user_group" {
    name = var.opensearch_user_group_name
}

resource "aws_iam_group_policy_attachment" "opensearch_access_group_policy" {
    group      = aws_iam_group.opensearch_user_group.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonOpenSearchServiceFullAccess"
}

# OpenSearch users
resource "aws_iam_user" "opensearch_users" {
    for_each = toset(var.users)
    name     = each.key
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
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}