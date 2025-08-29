# terraform-infra
Run:
  terraform init
  terraform apply

This provisions:
- VPC, EKS cluster (productapp-eks)
- ECR repos: productapp-api, productapp-ui
- IAM OIDC provider & role for GitHub Actions (OIDC)
- Helm installs: ingress-nginx, cert-manager, argocd (via helm_release)
- Route53 A record for gitops.dockeroncloud.com pointing at ingress LB

