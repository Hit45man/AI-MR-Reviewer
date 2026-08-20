# Standalone stack: shared networking module + Atlantis EC2.
# Apply this first. terraform/envs/dev reads VPC via remote state (no second VPC).
#
#   copy terraform.tfvars.example terraform.tfvars
#   copy backend.hcl.example backend.hcl
#   terraform init "-backend-config=backend.hcl"
#   terraform apply

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.tags, {
      env     = var.env
      project = var.project
    })
  }
}

locals {
  # EKS cluster name that envs/dev will create — subnet tags must match
  eks_cluster_name = var.eks_cluster_name != "" ? var.eks_cluster_name : "${var.project}-${var.platform_env}"
}

# Reuse the same networking module as the platform (VPC, public/private subnets, NAT, app SG)
module "networking" {
  source = "../../modules/networking"

  project      = var.project
  env          = var.platform_env
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
  cluster_name = local.eks_cluster_name
}

module "atlantis" {
  source = "../../modules/atlantis-ec2"

  project          = var.project
  env              = var.env
  aws_region       = var.aws_region
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]

  instance_type         = var.atlantis_instance_type
  key_name              = var.atlantis_key_name
  ssh_cidr_blocks       = var.atlantis_ssh_cidr_blocks
  webhook_cidr_blocks   = var.atlantis_webhook_cidr_blocks
  repo_allowlist        = var.atlantis_repo_allowlist
  atlantis_image        = var.atlantis_image
  root_volume_gb        = var.atlantis_root_volume_gb
  state_bucket_name     = var.state_bucket_name
  state_lock_table_name = var.state_lock_table_name
  kms_key_arn           = var.kms_key_arn
  attach_admin_access   = var.atlantis_attach_admin_access

  github_user           = var.atlantis_github_user
  github_token          = var.atlantis_github_token
  github_webhook_secret = var.atlantis_github_webhook_secret
  github_app_id         = var.atlantis_github_app_id
  github_app_key        = var.atlantis_github_app_key
}

# --- Networking outputs (consumed by terraform/envs/dev via remote state) ---

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "app_security_group_id" {
  value = module.networking.app_security_group_id
}

output "eks_cluster_name" {
  value = local.eks_cluster_name
}

# --- Atlantis outputs ---

output "atlantis_url" {
  value = module.atlantis.atlantis_url
}

output "atlantis_webhook_url" {
  value = module.atlantis.webhook_url
}

output "atlantis_vcs_secret_arn" {
  value = module.atlantis.vcs_secret_arn
}

output "atlantis_vcs_secret_name" {
  value = "${var.project}-${var.env}-atlantis-vcs"
}

output "atlantis_setup_hint" {
  value = module.atlantis.setup_hint
}
