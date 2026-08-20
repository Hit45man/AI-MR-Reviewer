variable "project" {
  description = "Project name prefix for resources"
  type        = string
}

variable "env" {
  description = "Stack name for Atlantis resources (e.g. atlantis)"
  type        = string
}

variable "platform_env" {
  description = "Platform env name used by modules/networking (must match envs/dev, e.g. dev)"
  type        = string
}

variable "eks_cluster_name" {
  description = "Future EKS cluster name for subnet tags. Empty = project-platform_env"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the shared platform VPC (modules/networking)"
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket Atlantis uses when applying terraform/envs/dev"
  type        = string
}

variable "state_lock_table_name" {
  description = "DynamoDB lock table for terraform/envs/dev"
  type        = string
}

variable "kms_key_arn" {
  description = "Optional KMS key for the Atlantis VCS secret. Empty = AWS-managed SM encryption."
  type        = string
  default     = ""
}

variable "atlantis_instance_type" {
  type = string
}

variable "atlantis_root_volume_gb" {
  type    = number
  default = 30
}

variable "atlantis_key_name" {
  description = "Optional EC2 key pair for SSH"
  type        = string
  default     = ""
}

variable "atlantis_ssh_cidr_blocks" {
  description = "CIDRs allowed to SSH. Empty disables SSH ingress."
  type        = list(string)
  default     = []
}

variable "atlantis_webhook_cidr_blocks" {
  description = "CIDRs allowed to reach Atlantis :4141"
  type        = list(string)
}

variable "atlantis_repo_allowlist" {
  description = "ATLANTIS_REPO_ALLOWLIST, e.g. github.com/owner/repo"
  type        = string
}

variable "atlantis_image" {
  description = "Atlantis container image"
  type        = string
}

variable "atlantis_attach_admin_access" {
  description = "POC: attach AdministratorAccess so Atlantis can apply envs/dev from PRs"
  type        = bool
}

variable "atlantis_github_user" {
  description = "Optional seed for Secrets Manager (prefer setting SM manually)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_token" {
  description = "Optional seed for Secrets Manager (prefer setting SM manually)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_webhook_secret" {
  description = "Optional seed for Secrets Manager (prefer setting SM manually)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_app_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "atlantis_github_app_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "tags" {
  type = map(string)
}
