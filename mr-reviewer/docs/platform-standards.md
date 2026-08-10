# Platform standards (banking template)

## Encryption

- Data stores (RDS, S3, SQS, Secrets Manager) must use customer-managed KMS keys (CMK).

## Secrets

- Never commit credentials or real `.env` values.
- Terraform creates secret shells; values set post-apply.
- Runtime: External Secrets / CSI from AWS Secrets Manager or Vault.

## Network

- Databases and internal APIs in private subnets only.
- No `0.0.0.0/0` on data-plane security groups.
- Document approved CIDRs; reject overlaps with reserved ranges.

## IAM

- No long-lived IAM users for humans in prod; SSO + roles.
- Least privilege; avoid `*` on sensitive actions without an ADR.

## Data / PCI

- Tags: `public` | `internal` | `confidential` | `restricted`.
- No PAN, CVV, or full account numbers in logs or PR descriptions.
- CDE workloads only in designated accounts/VPCs.

## Supply chain (Terraform)

- Pin module versions.
- Prefer internal module registry for prod.

## GitOps

- No literal Kubernetes Secret data in git.
- Prod images: digest or immutable tag (no `:latest`).
