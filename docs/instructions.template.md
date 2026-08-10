# MR Reviewer instructions — per-repo template

Copy to each watched GitHub repo root as `instructions.md`.

## Repo scope

What this repo owns (Terraform / GitOps / application) and regulatory scope.

## Mandatory rules

- Follow platform `naming-standard.md` and `platform-standards.md`.
- Add repo-specific musts (e.g. ExternalSecret only, Atlantis/project registration).

## Deliberate deviations — don't flag these

- Blessed legacy exceptions with owner/ticket.

## File-specific rules

- High-risk paths (bootstrap, IAM, KMS).
