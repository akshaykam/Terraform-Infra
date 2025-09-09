variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "productapp-eks-public"
}

variable "domain" {
  type    = string
  default = "gitops.dockeroncloud.com"
}

variable "github_org" {
  type    = string
  default = "your-gh-org" # replace with your GitHub org or username
}

variable "github_repo_ops" {
  type    = string
  default = "ops-gitops"
}

variable "public_zone_id" {
  type = string
  default = "Z287FG27N5HFVA" # fill with your Route53 Hosted Zone ID if you already have one
}