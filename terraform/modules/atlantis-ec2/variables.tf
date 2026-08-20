variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  description = "Public subnet for the Atlantis EC2 (needs a public IP / EIP for GitHub webhooks)"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH. Leave empty to disable key-based SSH."
  type        = string
  default     = ""
}

variable "ssh_cidr_blocks" {
  description = "CIDRs allowed to SSH (port 22). Empty = no SSH ingress."
  type        = list(string)
  default     = []
}

variable "webhook_cidr_blocks" {
  description = "CIDRs allowed to hit Atlantis webhook port 4141. POC default is open."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "repo_allowlist" {
  description = "Atlantis ATLANTIS_REPO_ALLOWLIST, e.g. github.com/org/repo"
  type        = string
}

variable "atlantis_image" {
  description = "Atlantis container image"
  type        = string
  default     = "ghcr.io/runatlantis/atlantis:v0.30.0"
}

variable "state_bucket_name" {
  description = "S3 bucket used by terraform/envs/dev backend"
  type        = string
}

variable "state_lock_table_name" {
  description = "DynamoDB lock table used by terraform/envs/dev backend"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for Secrets Manager (optional decrypt)"
  type        = string
  default     = ""
}

variable "attach_admin_access" {
  description = "POC: attach AdministratorAccess so Atlantis can apply the full stack. Tighten for non-POC."
  type        = bool
  default     = true
}

variable "github_user" {
  description = "GitHub username/bot for PAT auth (leave empty if using GitHub App)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_token" {
  description = "GitHub PAT (leave empty if using GitHub App). Stored in Secrets Manager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "Shared secret for GitHub → Atlantis webhooks"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_id" {
  description = "GitHub App ID (optional alternative to PAT)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_key" {
  description = "GitHub App private key PEM contents (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "root_volume_gb" {
  type    = number
  default = 30
}
