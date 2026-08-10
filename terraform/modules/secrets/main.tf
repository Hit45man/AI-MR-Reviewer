variable "project" { type = string }
variable "env" { type = string }

resource "aws_kms_key" "secrets" {
  description             = "${var.project}-${var.env} secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}-${var.env}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

locals {
  litellm_secrets = [
    "litellm-master-key",
  ]
  reviewer_secrets = [
    "github-token",
    "github-webhook-secret",
    "github-app-id",
    "github-app-private-key",
    "litellm-api-key",
  ]
}

resource "aws_secretsmanager_secret" "litellm" {
  for_each                = toset(local.litellm_secrets)
  name                    = "${var.project}-${var.env}-${each.value}"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "reviewer" {
  for_each                = toset(local.reviewer_secrets)
  name                    = "${var.project}-${var.env}-${each.value}"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
}

# Placeholder versions — replace post-apply with real values
resource "random_password" "litellm_master" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret_version" "litellm_master" {
  secret_id     = aws_secretsmanager_secret.litellm["litellm-master-key"].id
  secret_string = "sk-${random_password.litellm_master.result}"
}

output "kms_key_arn" { value = aws_kms_key.secrets.arn }
output "litellm_secret_arns" {
  value = { for k, s in aws_secretsmanager_secret.litellm : k => s.arn }
}
output "reviewer_secret_arns" {
  value = { for k, s in aws_secretsmanager_secret.reviewer : k => s.arn }
}
