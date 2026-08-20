# Atlantis POC — optional second instance inside envs/dev (prefer terraform/envs/atlantis-poc).
# Uses the shared VPC from atlantis-poc remote state.

module "atlantis" {
  count  = var.enable_atlantis ? 1 : 0
  source = "../../modules/atlantis-ec2"

  project          = var.project
  env              = var.env
  aws_region       = var.aws_region
  vpc_id           = local.vpc_id
  public_subnet_id = local.public_subnet_ids[0]

  instance_type         = var.atlantis_instance_type
  key_name              = var.atlantis_key_name
  ssh_cidr_blocks       = var.atlantis_ssh_cidr_blocks
  webhook_cidr_blocks   = var.atlantis_webhook_cidr_blocks
  repo_allowlist        = var.atlantis_repo_allowlist
  atlantis_image        = var.atlantis_image
  state_bucket_name     = var.atlantis_poc_state_bucket
  state_lock_table_name = var.state_lock_table_name
  kms_key_arn           = module.secrets.kms_key_arn
  attach_admin_access   = var.atlantis_attach_admin_access

  github_user           = var.atlantis_github_user
  github_token          = var.atlantis_github_token
  github_webhook_secret = var.atlantis_github_webhook_secret
  github_app_id         = var.atlantis_github_app_id
  github_app_key        = var.atlantis_github_app_key
}

output "atlantis_url" {
  value       = var.enable_atlantis ? module.atlantis[0].atlantis_url : null
  description = "Atlantis base URL (POC HTTP)"
}

output "atlantis_webhook_url" {
  value       = var.enable_atlantis ? module.atlantis[0].webhook_url : null
  description = "GitHub webhook Payload URL"
}

output "atlantis_vcs_secret_arn" {
  value       = var.enable_atlantis ? module.atlantis[0].vcs_secret_arn : null
  description = "Secrets Manager ARN for Atlantis GitHub credentials"
}

output "atlantis_setup_hint" {
  value = var.enable_atlantis ? module.atlantis[0].setup_hint : null
}

output "shared_vpc_id" {
  value       = local.vpc_id
  description = "VPC from atlantis-poc (modules/networking)"
}
