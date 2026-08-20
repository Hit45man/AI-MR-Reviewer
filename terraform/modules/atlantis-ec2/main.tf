locals {
  name_prefix = "${var.project}-${var.env}-atlantis"

  # Server-side repo config (POC: no approval gate; allow repo atlantis.yaml workflows)
  repos_yaml = <<-YAML
  repos:
    - id: /.*/
      apply_requirements: []
      allowed_overrides: [workflow, apply_requirements, delete_source_branch_on_merge]
      allow_custom_workflows: true
  YAML

  secret_payload = jsonencode({
    gh_user           = var.github_user
    gh_token          = var.github_token
    gh_webhook_secret = var.github_webhook_secret
    gh_app_id         = var.github_app_id
    gh_app_key        = var.github_app_key
  })
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_eip" "this" {
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-eip" }
}

resource "aws_security_group" "this" {
  name_prefix = "${local.name_prefix}-"
  description = "Atlantis POC EC2"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.ssh_cidr_blocks) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
    }
  }

  ingress {
    description = "Atlantis webhook / UI"
    from_port   = 4141
    to_port     = 4141
    protocol    = "tcp"
    cidr_blocks = var.webhook_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "this" {
  name = local.name_prefix

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = local.name_prefix }
}

resource "aws_iam_role_policy" "state_and_secrets" {
  name = "atlantis-state-secrets"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
        ]
        Resource = ["arn:aws:s3:::${var.state_bucket_name}"]
      },
      {
        Sid    = "TerraformStateObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = ["arn:aws:s3:::${var.state_bucket_name}/*"]
      },
      {
        Sid    = "TerraformLock"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table_name}"
        ]
      },
      {
        Sid      = "ReadAtlantisSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [aws_secretsmanager_secret.vcs.arn]
      },
      {
        Sid      = "DecryptSecrets"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn != "" ? [var.kms_key_arn] : ["*"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "admin" {
  count      = var.attach_admin_access ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "this" {
  name = local.name_prefix
  role = aws_iam_role.this.name
}

resource "aws_secretsmanager_secret" "vcs" {
  name                    = "${local.name_prefix}-vcs"
  description             = "Atlantis GitHub credentials (PAT or App) + webhook secret"
  kms_key_id              = var.kms_key_arn != "" ? var.kms_key_arn : null
  recovery_window_in_days = 7

  tags = { Name = "${local.name_prefix}-vcs" }
}

resource "aws_secretsmanager_secret_version" "vcs" {
  secret_id     = aws_secretsmanager_secret.vcs.id
  secret_string = local.secret_payload
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region     = var.aws_region
    secrets_arn    = aws_secretsmanager_secret.vcs.arn
    atlantis_url   = "http://${aws_eip.this.public_ip}:4141"
    repo_allowlist = var.repo_allowlist
    atlantis_image = var.atlantis_image
    repos_yaml     = local.repos_yaml
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name     = local.name_prefix
    Role     = "atlantis"
    Workload = "atlantis-poc"
  }

  depends_on = [
    aws_iam_role_policy.state_and_secrets,
    aws_iam_role_policy_attachment.ssm,
  ]
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
