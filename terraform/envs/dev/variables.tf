variable "project" {
  type    = string
  default = "mr-reviewer"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  description = "Unused for VPC create when networking is owned by atlantis-poc; kept for docs/compat"
  type        = string
  default     = "10.40.0.0/16"
}

variable "atlantis_poc_state_bucket" {
  description = "S3 bucket holding atlantis-poc state (shared VPC outputs)"
  type        = string
  default     = "mr-reviewer-dev-tfstate"
}

variable "atlantis_poc_state_key" {
  description = "State key for atlantis-poc (networking + Atlantis server)"
  type        = string
  default     = "atlantis-poc/terraform.tfstate"
}

variable "state_lock_table_name" {
  description = "DynamoDB lock table used by Atlantis when applying this stack"
  type        = string
  default     = "mr-reviewer-dev-tfstate-lock"
}

variable "db_username" {
  type    = string
  default = "mr_reviewer"
}

variable "watched_repos" {
  description = "Comma-separated GitHub repos org/name (used in gitops manifests / docs)"
  type        = string
  default     = "my-org/terraform-infra,my-org/gitops"
}

variable "node_instance_type" {
  description = "EKS managed node instance type (POC: one small node)"
  type        = string
  default     = "t3.medium"
}

variable "cluster_version" {
  description = "EKS Kubernetes version (must be currently supported by AWS)"
  type        = string
  default     = "1.34"
}

variable "node_desired_size" {
  description = "Managed node group size (POC: 1)"
  type        = number
  default     = 1
}

variable "git_repo_url" {
  description = "Git repo URL Argo CD syncs (gitops/ path). Use HTTPS or SSH."
  type        = string
  default     = "https://github.com/EXAMPLE/aws-mr-reviewer.git"
}

variable "git_repo_revision" {
  description = "Git revision for Argo CD Application"
  type        = string
  default     = "HEAD"
}

variable "tags" {
  type = map(string)
  default = {
    managed-by = "terraform"
    workload   = "mr-reviewer"
  }
}

# --- Atlantis POC (EC2) ---

variable "enable_atlantis" {
  description = "Create a dedicated EC2 instance running Atlantis (cheaper than EKS for POC)"
  type        = bool
  default     = false
}

variable "atlantis_instance_type" {
  type    = string
  default = "t3.small"
}

variable "atlantis_key_name" {
  description = "EC2 key pair for SSH (optional; SSM Session Manager works without it)"
  type        = string
  default     = ""
}

variable "atlantis_ssh_cidr_blocks" {
  description = "CIDRs allowed to SSH to Atlantis. Empty disables SSH ingress."
  type        = list(string)
  default     = []
}

variable "atlantis_webhook_cidr_blocks" {
  description = "CIDRs allowed to reach Atlantis :4141 (GitHub webhooks). Open for POC."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "atlantis_repo_allowlist" {
  description = "ATLANTIS_REPO_ALLOWLIST — github.com/owner/repo"
  type        = string
  default     = "github.com/Hit45man/AI-MR-Reviewer"
}

variable "atlantis_image" {
  type    = string
  default = "ghcr.io/runatlantis/atlantis:v0.42.0"
}

variable "atlantis_attach_admin_access" {
  description = "POC convenience: AdministratorAccess on the Atlantis instance role. Disable / tighten for real use."
  type        = bool
  default     = true
}

variable "atlantis_github_user" {
  description = "GitHub username/bot for PAT auth"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_token" {
  description = "GitHub PAT with repo + PR permissions (or use GitHub App vars instead)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_webhook_secret" {
  description = "Shared secret for the GitHub → Atlantis webhook"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_app_id" {
  description = "Optional GitHub App ID (alternative to PAT)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_github_app_key" {
  description = "Optional GitHub App private key PEM"
  type        = string
  default     = ""
  sensitive   = true
}
