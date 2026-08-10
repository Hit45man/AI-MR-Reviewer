# How to build & ship mr-reviewer

## Short answer

| Question | Answer |
|----------|--------|
| Was a pipeline created originally? | **No** — only `mr-reviewer/Dockerfile` |
| What exists now? | **GitHub Actions**: `.github/workflows/mr-reviewer-ci.yml` + PR checks |
| Horizon equivalent | `horizon-mr-reviewer/.gitlab-ci.yml` (build → bump-gitops) |

## Build locally (dev)

```bash
cd c:\Web-PT\aws-mr-reviewer\mr-reviewer

# 1) Run without Docker
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
set LITELLM_URL=http://localhost:4000
set PRIMARY_MODEL=nova-pro
set FALLBACK_MODEL=nova-lite
set EMBEDDING_MODEL=titan-embed-v2
uvicorn src.main:app --reload --port 8080

# 2) Or build the container
docker build -t mr-reviewer:local .
docker run --rm -p 8080:8080 ^
  -e LITELLM_URL=http://host.docker.internal:4000 ^
  -e PRIMARY_MODEL=nova-pro ^
  -e GITHUB_TOKEN=ghp_xxx ^
  mr-reviewer:local
```

## Production build flow (same idea as Horizon)

```
push to main (mr-reviewer/**)
        │
        ▼
 GitHub Actions: mr-reviewer-ci
        │
        ├─1─ docker build (Dockerfile)
        ├─2─ push to Amazon ECR  : <short-sha>
        └─3─ bump gitops/apps/mr-reviewer/deployment.yaml image tag
                │
                ▼
         Argo CD syncs EKS (gitops/)
```

Horizon did this with **GitLab CI** → Artifact Registry → bump `horizon-gitops` images.yaml.  
Here it is **GitHub Actions** → **ECR** → bump in-repo `gitops/` → **Argo CD** rolls out on EKS.

## Pipeline files

1. **`.github/workflows/mr-reviewer-ci.yml`** (on `main`)
   - OIDC login to AWS
   - Build + push ECR image tagged with commit short SHA
   - Commit updated image tag in `gitops/apps/mr-reviewer/deployment.yaml`

2. **`.github/workflows/mr-reviewer-pr-checks.yml`** (on PRs)
   - Install Python deps, parse-check `src/`
   - `docker build` without push

## Secrets / vars you must set in GitHub

| Name | Type | Purpose |
|------|------|---------|
| `AWS_ROLE_TO_ASSUME` | secret | IAM role ARN for OIDC (ECR push) — Terraform output `github_actions_role_arn` |
| `AWS_ACCOUNT_ID` | secret | 12-digit account id — Terraform output `aws_account_id` |
| `AWS_REGION` | variable | e.g. `ap-south-1` (optional; workflow defaults to `ap-south-1`) |

After `terraform apply` in `terraform/envs/dev`:

```bash
terraform output github_actions_role_arn
terraform output aws_account_id
```

Add those as **GitHub → repo Settings → Secrets and variables → Actions**.

ECR repo `mr-reviewer` is created by Terraform (`aws_ecr_repository.mr_reviewer`).
## What is NOT automated yet

- Terraform apply (run separately / Atlantis / another workflow)
- LiteLLM image build (uses public `ghcr.io/berriai/litellm` + ConfigMap mount)
- Syncing AWS Secrets Manager → Kubernetes Secrets (create K8s secrets manually for POC)

## Recommended bank flow

1. PR → `mr-reviewer-pr-checks` must pass  
2. Merge to `main` → CI builds SHA-tagged image  
3. GitOps syncs → only then does the bot update in AWS  
4. Never deploy `:latest` to prod (CI still pushes `:main` for convenience; GitOps should pin the SHA)
