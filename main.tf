locals {
  account_id = "543816070942"
  region     = "us-east-1"
  domain     = "gitops.dockeroncloud.com"
  aws_ecr_api = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/productapp-api"
  aws_ecr_ui  = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/productapp-ui"
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 4.0"
  name = "productapp-vpc"
  cidr = "10.10.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = ["10.10.1.0/24","10.10.2.0/24","10.10.3.0/24"]
  private_subnets = ["10.10.11.0/24","10.10.12.0/24","10.10.13.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

data "aws_availability_zones" "available" {}

# EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  manage_aws_auth = true

  node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 2
      instance_types   = ["t3.medium"]
    }
  }
}

# ECR repositories
resource "aws_ecr_repository" "api" {
  name = "productapp-api"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "ui" {
  name = "productapp-ui"
  image_tag_mutability = "MUTABLE"
}

# IAM OIDC provider for GitHub Actions (OIDC)
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub thumbprint
}

# Create role for GitHub Actions using OIDC
resource "aws_iam_role" "github_actions_oidc" {
  name = "GitHubActionsOIDCRole-productapp"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*"
          }
        }
      }
    ]
  })
}

# minimal policy to push to ECR
resource "aws_iam_policy" "github_ecr_policy" {
  name = "GitHubActionsECRProductAppPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "iam:ListRoles",
          "sts:AssumeRole"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_github_ecr" {
  role = aws_iam_role.github_actions_oidc.name
  policy_arn = aws_iam_policy.github_ecr_policy.arn
}

# Helm provider config for after cluster is created
provider "kubernetes" {
  host = module.eks.cluster_endpoint

  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token = data.aws_eks_cluster_auth.cluster.token
  }
}

# Install ingress-nginx via Helm
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true

  values = [
    file("${path.module}/helm-values/ingress-nginx-values.yaml")
  ]
}

# Install cert-manager (so we can get LetsEncrypt certs)
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Install ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true

  values = [
    file("${path.module}/helm-values/argocd-values.yaml")
  ]
}

# Route53 record (if hosted zone provided)
# user should set variable public_zone_id (your hosted zone)
resource "aws_route53_record" "productapp" {
  count = length(var.public_zone_id) > 0 ? 1 : 0
  zone_id = var.public_zone_id
  name    = local.domain
  type    = "A"
  alias {
    name = helm_release.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
    zone_id = helm_release.nginx_ingress.status[0].load_balancer[0].ingress[0].zone_id
    evaluate_target_health = false
  }
}

# Output values
#output "cluster_name" {
#  value = module.eks.cluster_id
#}
output "kubeconfig" {
  value = module.eks.kubeconfig
  sensitive = true
}
output "ecr_api" {
  value = aws_ecr_repository.api.repository_url
}
output "ecr_ui" {
  value = aws_ecr_repository.ui.repository_url
}
output "argocd_url" {
  value = "Argo CD installed in namespace argocd (server is ClusterIP). Port-forward or expose if needed."
}
