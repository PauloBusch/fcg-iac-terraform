# Cluster
resource "aws_eks_cluster" "eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]

    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy
  ]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

# Nodes
resource "aws_eks_node_group" "fcg_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "fcg-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  instance_types = ["t3.small"]

  scaling_config {
    desired_size = var.eks_desired_capacity
    min_size     = var.eks_min_size
    max_size     = var.eks_max_size
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy
  ]
}

# Namespaces
resource "kubernetes_namespace" "fcg_namespaces" {
  for_each = { for ms in var.microservices_config : ms.key => ms }
  metadata {
    name = "fcg-${each.key}"
  }
}

# Ingress
resource "kubernetes_ingress_v1" "fcg_ingress" {
  for_each = { for ms in var.microservices_config : ms.key => ms }

  metadata {
    name      = "fcg-${each.key}-ingress"
    namespace = "fcg-${each.key}"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
    }
  }
  spec {
    ingress_class_name = "fcg-alb"
    rule {
      http {
        path {
          path      = "/${each.key}"
          path_type = "Prefix"
          backend {
            service {
              name = "fcg-${each.key}-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# ALB (Application Load Balancer)
resource "kubernetes_ingress_class_v1" "fcg_alb" {
  metadata {
    name = "fcg-alb"
  }
  spec {
    controller = "ingress.k8s.aws/alb"
  }
}

# Secrets
resource "kubernetes_secret" "fcg_secrets" {
  for_each = { for ms in var.microservices_config : ms.key => ms }

  metadata {
    name      = "fcg-${each.key}-secrets"
    namespace = "fcg-${each.key}"
  }

  data = merge(
    {
      ElasticSearchAccessKey = aws_iam_access_key.opensearch_users_access_key[each.key].id
      ElasticSearchSecret    = aws_iam_access_key.opensearch_users_access_key[each.key].secret
    },
    contains(keys(aws_sqs_queue.fcg_sqs), each.key) ? {
      AwsSqsAccessKey = aws_iam_access_key.sqs_users_access_key[each.key].id
      AwsSqsSecret     = aws_iam_access_key.sqs_users_access_key[each.key].secret
    } : {}
  )
}

# Config Maps
resource "kubernetes_config_map" "fcg_configmaps" {
  for_each = { for ms in var.microservices_config : ms.key => ms }

  metadata {
    name      = "fcg-${each.key}-configs"
    namespace = "fcg-${each.key}"
  }

  data = merge(
    {
      ElasticSearchEndpoint = "https://${aws_opensearch_domain.fcg.endpoint}"
      ElasticSearchRegion   = aws_opensearch_domain.fcg.region
    },
    contains(keys(aws_sqs_queue.fcg_sqs), each.key) ? {
      AwsSqsUrl  = aws_sqs_queue.fcg_sqs[each.key].url
    } : {}
  )
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.eks_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      {
        rolearn  = aws_iam_role.eks_cluster_role.arn
        username = "eks-cluster-role"
        groups   = ["system:masters"]
      },
      {
        rolearn  = aws_iam_role.codebuild_role.arn
        username = "codebuild"
        groups   = ["system:masters"]
      }
    ])
  }
  depends_on = [aws_eks_cluster.eks]
}