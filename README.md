# AWS MR Reviewer Platform (GitHub + Bedrock-only)

Standalone platform **outside** `horizon-infra`. AI pull-request reviewer for a banking (or any) client on **AWS**, using:

- **GitHub** (PRs + webhooks) — not GitLab
- **Amazon Bedrock** as the only model backend (no Anthropic API, no Vertex, no OpenAI.com)
- **LiteLLM** as the OpenAI-compatible proxy in front of Bedrock
- **MR Reviewer** FastAPI service (webhook → RAG → review comment on the PR)
- **Terraform** for VPC, RDS, secrets, **EKS** (POC: 1× `t3.medium`), IRSA, AWS LB Controller, Argo CD
- **GitOps** manifests synced by Argo CD for LiteLLM + MR Reviewer

```
GitHub pull_request / issue_comment webhook
        │
        ▼
  mr-reviewer (EKS / Argo CD)
        │  OpenAI SDK → http://litellm:4000/v1
        ▼
     LiteLLM
        │  aliases: nova-pro | nova-lite | titan-embed-v2
        ▼
  Amazon Bedrock
   • amazon.nova-pro-v1:0             (primary chat)
   • amazon.nova-lite-v1:0            (fallback chat)
   • amazon.titan-embed-text-v2:0     (embeddings / RAG)
        ▲
  RDS PostgreSQL + pgvector
```

## Layout

| Path | Purpose |
|------|---------|
| `docs/` | Naming + platform standards + setup (GitHub) |
| `terraform/` | VPC, RDS, secrets, EKS + IRSA + Argo CD; `bootstrap/` = S3 remote state; `envs/atlantis-poc` = Atlantis EC2 only; `modules/atlantis-ec2` |
| `atlantis.yaml` | Atlantis project config (`terraform/envs/dev` only) |
| `atlantis/` | Reference Atlantis server `repos.yaml` |
| `litellm/` | Bedrock-only `proxy_config.yaml` |
| `mr-reviewer/` | Reviewer app (GitHub App / PAT) |
| `gitops/` | Deploy manifests (Argo CD target) |
| `scripts/` | Index bootstrap |

## Model policy

**Allowed:** Amazon Bedrock foundation models only.  
**Not configured:** Anthropic direct API, Azure OpenAI, Vertex AI, OpenAI.com.

Enable model access in the Bedrock console for your region before deploy.
