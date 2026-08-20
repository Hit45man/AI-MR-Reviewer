output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_eip.this.public_ip
}

output "atlantis_url" {
  value = "http://${aws_eip.this.public_ip}:4141"
}

output "webhook_url" {
  value = "http://${aws_eip.this.public_ip}:4141/events"
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "iam_role_arn" {
  value = aws_iam_role.this.arn
}

output "vcs_secret_arn" {
  value = aws_secretsmanager_secret.vcs.arn
}

output "setup_hint" {
  value = <<-EOT
    1. Put GitHub creds in Secrets Manager (${aws_secretsmanager_secret.vcs.name}) as JSON:
       {"gh_user":"...","gh_token":"...","gh_webhook_secret":"...","gh_app_id":"","gh_app_key":""}
       Or set atlantis_github_* variables and re-apply.
    2. SSH/SSM: sudo systemctl restart atlantis   (if you updated the secret after boot)
    3. GitHub webhook → ${aws_eip.this.public_ip}:4141/events  (secret = gh_webhook_secret)
    4. Open a PR changing terraform/envs/dev → Atlantis plans via root atlantis.yaml
  EOT
}
