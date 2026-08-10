# GitHub webhook setup (org or repo)

1. GitHub → Settings → Webhooks → Add webhook
2. Payload URL: `https://mr-reviewer.<your-domain>/webhook`
3. Content type: `application/json`
4. Secret: value stored in AWS Secrets Manager `mr-reviewer-dev-github-webhook-secret`
5. SSL verification: enable
6. Events: **Let me select**
   - Pull requests
   - Issue comments
7. Active: yes

## Permissions (PAT or GitHub App)

- `contents: read`
- `pull_requests: write` (to post review comments)
- `metadata: read`

## Test

```bash
# Open a PR that violates naming-standard.md — expect a PR comment from the bot
curl -s https://mr-reviewer.<domain>/healthz
```
