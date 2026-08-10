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
  type    = string
  default = "10.40.0.0/16"
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
