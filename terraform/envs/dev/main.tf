terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  # Create bucket + lock table first: terraform/bootstrap (one-time)
  backend "s3" {
    bucket         = "mr-reviewer-dev-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "mr-reviewer-dev-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.tags, { env = var.env, project = var.project })
  }
}

locals {
  cluster_name = "${var.project}-${var.env}"
}

module "networking" {
  source = "../../modules/networking"

  project      = var.project
  env          = var.env
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
  cluster_name = local.cluster_name
}

module "secrets" {
  source = "../../modules/secrets"

  project = var.project
  env     = var.env
}

module "eks" {
  source = "../../modules/eks"

  project            = var.project
  env                = var.env
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_desired_size
  node_max_size      = max(var.node_desired_size, 1)
  cluster_version    = var.cluster_version
}

module "rds" {
  source = "../../modules/rds-pgvector"

  project            = var.project
  env                = var.env
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  db_username        = var.db_username
  allowed_sg_ids = [
    module.eks.cluster_security_group_id,
    module.networking.app_security_group_id,
  ]
  kms_key_arn = module.secrets.kms_key_arn
}

# Kubernetes / Helm talk to the cluster after EKS is up (exec avoids token chicken-egg)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region,
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region,
      ]
    }
  }
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = module.eks.configure_kubectl
}

output "litellm_irsa_role_arn" {
  value = module.eks.litellm_role_arn
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "argocd_server_hint" {
  value = "kubectl -n argocd port-forward svc/argocd-server 8080:443  # then open https://localhost:8080"
}

output "webhook_url_hint" {
  value = "After Argo sync: kubectl -n platform get ingress mr-reviewer → https://<ADDRESS>/webhook"
}
