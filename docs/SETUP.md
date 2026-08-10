# Setup runbook — GitHub + AWS Bedrock (EKS + Argo CD)

## Prerequisites

- AWS account with Bedrock access enabled for:
  - `amazon.nova-pro-v1:0`
  - `amazon.nova-lite-v1:0`
  - `amazon.titan-embed-text-v2:0`
- Terraform >= 1.5, AWS CLI, Docker, `kubectl`
- GitHub org with permission to create:
  - A **GitHub App** (recommended) or fine-grained PAT
  - Repository / org webhooks
- A reachable git remote for this repo (Argo CD syncs `gitops/`)

## GitHub auth (pick one)

### Option A — GitHub App (recommended for banks)

1. Create GitHub App: Permissions → Contents (read), Pull requests (read/write), Issues (read/write for PR comments).
2. Subscribe to events: `Pull request`, `Issue comment`, `Push` (optional for reindex).
3. Install on watched repos/org.
4. Store credentials in K8s secrets (and optionally AWS Secrets Manager for backup).

### Option B — Fine-grained PAT (POC only)

1. PAT with `contents:read`, `pull_requests:write` on watched repos.
2. Store as `GITHUB_TOKEN` + webhook secret in `mr-reviewer-secrets`.

## Steps (EKS POC)

1. Customize `docs/naming-standard.md` and `docs/platform-standards.md`.
2. Authenticate to AWS (`aws configure` / `AWS_PROFILE`) and verify: `aws sts get-caller-identity`.
3. **Bootstrap remote state (one-time)** — S3 bucket `mr-reviewer-dev-tfstate` + DynamoDB lock table:
   ```powershell
   cd C:\Web-PT\aws-mr-reviewer\terraform\bootstrap
   terraform init
   terraform apply
   ```
   This stack keeps its own *local* state (only the backend resources). Do not destroy it while `envs/dev` is in use.
4. `cd terraform/envs/dev`
   - `copy terraform.tfvars.example terraform.tfvars`
   - Set `git_repo_url` to **your** clone/remote (Argo CD will sync it)
   - Keep `node_desired_size = 1` and `node_instance_type = "t3.medium"` for POC
5. `terraform init` → `terraform apply`
   - State is stored in S3 (`dev/terraform.tfstate`) with DynamoDB locking
   - If you already applied with local state: `terraform init -migrate-state`
   - Creates VPC, RDS pgvector, Secrets Manager, EKS (1 node), IRSA (LiteLLM→Bedrock), AWS LB Controller, Argo CD + root Application
6. Configure kubectl (Terraform output `configure_kubectl`):
   ```bash
   aws eks update-kubeconfig --region ap-south-1 --name mr-reviewer-dev
   ```
7. Create platform secrets (required before pods are Ready):
   ```bash
   # DATABASE_URL / master key also live in Secrets Manager after apply
   kubectl -n platform create secret generic litellm-secrets \
     --from-literal=LITELLM_MASTER_KEY='sk-...' \
     --from-literal=DATABASE_URL='postgresql://...'

   kubectl -n platform create secret generic mr-reviewer-secrets \
     --from-literal=LITELLM_API_KEY='sk-...' \
     --from-literal=GITHUB_TOKEN='ghp_...' \
     --from-literal=GITHUB_WEBHOOK_SECRET='...' \
     --from-literal=DATABASE_URL='postgresql://...'
   ```
8. Open Argo CD (POC):
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   # https://localhost:8080  user: admin
   ```
   Confirm Application `aws-mr-reviewer` is Synced (LiteLLM + MR Reviewer in `platform`).
9. Get webhook URL from Ingress ALB:
   ```bash
   kubectl -n platform get ingress mr-reviewer
   # Register GitHub webhook → http(s)://<ADDRESS>/webhook
   ```
10. Build/push `mr-reviewer` image (CI bumps `gitops/apps/mr-reviewer/deployment.yaml`); Argo CD auto-syncs.
11. Run full index: `POST /index` or `scripts/bootstrap_index.sh`.
12. Open a test PR with a known violation; confirm PR comment.

## Terraform remote state

| Resource | Name |
|----------|------|
| S3 bucket | `mr-reviewer-dev-tfstate` (versioned + encrypted + public access blocked) |
| Object key | `dev/terraform.tfstate` |
| DynamoDB lock | `mr-reviewer-dev-tfstate-lock` |
| Region | `ap-south-1` |

Bootstrap lives in `terraform/bootstrap/` (local state). App stack in `terraform/envs/dev/` uses the S3 backend above.

## Env vars (mr-reviewer)

| Variable | Example |
|----------|---------|
| `LITELLM_URL` | `http://litellm.platform.svc.cluster.local:4000` |
| `LITELLM_API_KEY` | K8s secret `mr-reviewer-secrets` |
| `PRIMARY_MODEL` | `nova-pro` |
| `FALLBACK_MODEL` | `nova-lite` |
| `EMBEDDING_MODEL` | `titan-embed-v2` |
| `DATABASE_URL` | RDS + pgvector |
| `GITHUB_API_URL` | `https://api.github.com` (or GHES URL) |
| `GITHUB_TOKEN` | PAT (if not using App) |
| `GITHUB_APP_ID` / `GITHUB_APP_PRIVATE_KEY` | App auth |
| `GITHUB_WEBHOOK_SECRET` | HMAC secret |
| `WATCHED_REPOS` | `org/terraform-infra,org/gitops` |
