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
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/subnets"     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
      "alb.ingress.kubernetes.io/group.name" = "fcg-shared-alb"
    }
  }
  spec {
    ingress_class_name = kubernetes_ingress_class_v1.fcg_alb_ingress_class.metadata[0].name
    rule {
      http {
        path {
          path      = "/${each.key}"
          path_type = "Prefix"
          backend {
            service {
              name = "fcg-${each.key}-service"
              port {
                number = each.value.service_port
              }
            }
          }
        }
      }
    }
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

# ALB (Application Load Balancer)
resource "kubernetes_ingress_class_v1" "fcg_alb_ingress_class" {
  metadata {
    name = "fcg-alb-ingress-class"
  }

  spec {
    controller = "ingress.k8s.aws/alb"
  }
}

resource "kubernetes_service_account" "fcg_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }
  }
}

resource "kubernetes_cluster_role_binding" "fcg_load_balancer_controller" {
  metadata {
    name = "aws-load-balancer-controller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "aws-load-balancer-controller"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fcg_load_balancer_controller.metadata[0].name
    namespace = kubernetes_service_account.fcg_load_balancer_controller.metadata[0].namespace
  }
}

resource "kubernetes_cluster_role" "fcg_load_balancer_controller" {
  metadata {
    name = "aws-load-balancer-controller"
  }
  rule {
    api_groups = ["", "extensions", "apps"]
    resources  = ["configmaps", "endpoints", "events", "ingresses", "ingresses/status", "services", "pods", "secrets"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "ingresses/status", "ingressclasses"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch", "create", "patch", "update", "delete"]
  }
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
    verbs      = ["get", "list", "watch", "create", "patch", "update", "delete"]
  }
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "patch", "update", "delete"]
  }
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

resource "helm_release" "fcg_load_balancer_controller" {
  name       = "fcg-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.eks.name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = aws_vpc.main.id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account.fcg_load_balancer_controller.metadata[0].name
    }
  ]

  depends_on = [
    aws_eks_cluster.eks,
    kubernetes_service_account.fcg_load_balancer_controller,
    kubernetes_cluster_role_binding.fcg_load_balancer_controller
  ]
}