# GitHub Actions OIDC → AWS (ECR push for mr-reviewer-ci.yml)
data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Official GitHub Actions OIDC thumbprints
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b9ad698bea4abfa18ac",
  ]

  tags = {
    Name = "${var.project}-${var.env}-github-oidc"
  }
}

resource "aws_ecr_repository" "mr_reviewer" {
  name                 = "mr-reviewer"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "mr-reviewer"
  }
}

locals {
  github_repo    = "Hit45man/AI-MR-Reviewer"
  # GitHub immutable OIDC sub (repos created after Jul 2026): repo:owner@OWNER_ID/name@REPO_ID:...
  github_owner_id = "78225117"
  github_repo_id  = "1329816649"
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project}-${var.env}-github-actions"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      # sts:TagSession is required by aws-actions/configure-aws-credentials@v4
      Action = [
        "sts:AssumeRoleWithWebIdentity",
        "sts:TagSession",
      ]
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            # Legacy name-only format
            "repo:${local.github_repo}:*",
            # Immutable ID format (this repo — from CloudTrail)
            "repo:Hit45man@${local.github_owner_id}/AI-MR-Reviewer@${local.github_repo_id}:*",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
        ]
        Resource = aws_ecr_repository.mr_reviewer.arn
      },
    ]
  })
}

output "github_actions_role_arn" {
  description = "Set GitHub secret AWS_ROLE_TO_ASSUME to this ARN"
  value       = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  description = "Set GitHub secret AWS_ACCOUNT_ID to this value"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.mr_reviewer.repository_url
}
