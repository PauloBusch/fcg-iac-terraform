variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "opensearch_domain" {
  description = "Name of the OpenSearch domain"
  type        = string
  default     = "fcg-opensearch"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "fcg-eks-cluster"
}

variable "eks_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "eks_min_size" {
  description = "Minimum nodes in node group"
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum nodes in node group"
  type        = number
  default     = 4
}