"""GitHub webhook receiver — pull_request + issue_comment."""
from __future__ import annotations

import hashlib
import hmac
import logging

from fastapi import APIRouter, Header, HTTPException, Request

from src.config import settings
from src.github_client import GitHubClient
from src.reviewer import review_pull_request

logger = logging.getLogger(__name__)
router = APIRouter()


def _verify_signature(payload: bytes, signature: str | None) -> None:
    if not settings.github_webhook_secret:
        logger.warning("GITHUB_WEBHOOK_SECRET unset — skipping signature verify (dev only)")
        return
    if not signature or not signature.startswith("sha256="):
        raise HTTPException(status_code=401, detail="missing signature")
    digest = hmac.new(
        settings.github_webhook_secret.encode(),
        payload,
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(f"sha256={digest}", signature):
        raise HTTPException(status_code=401, detail="bad signature")


@router.post("/webhook")
async def github_webhook(
    request: Request,
    x_hub_signature_256: str | None = Header(default=None),
    x_github_event: str | None = Header(default=None),
):
    body = await request.body()
    _verify_signature(body, x_hub_signature_256)
    event = x_github_event or ""
    payload = await request.json()

    if event == "pull_request":
        action = payload.get("action")
        if action not in {"opened", "synchronize", "reopened"}:
            return {"ok": True, "skipped": action}
        pr = payload["pull_request"]
        repo = payload["repository"]
        owner = repo["owner"]["login"]
        name = repo["name"]
        full = repo["full_name"]
        if settings.repo_list and full not in settings.repo_list:
            return {"ok": True, "skipped": "not watched"}
        number = pr["number"]
        gh = GitHubClient()
        files = await gh.get_pr_files(owner, name, number)
        review, model = await review_pull_request(owner, name, number, files)
        comment = f"## MR Reviewer (Bedrock / `{model}`)\n\n{review}"
        await gh.post_pr_comment(owner, name, number, comment)
        return {"ok": True, "reviewed": full, "pr": number, "model": model}

    if event == "issue_comment":
        # Optional: @mr-reviewer review / skip / remember — extend like Horizon
        comment = payload.get("comment", {})
        user = (comment.get("user") or {}).get("login", "")
        if user == settings.bot_login:
            return {"ok": True, "skipped": "own comment"}
        body_text = comment.get("body") or ""
        if "@mr-reviewer review" in body_text.lower() and payload.get("issue", {}).get("pull_request"):
            repo = payload["repository"]
            owner = repo["owner"]["login"]
            name = repo["name"]
            number = payload["issue"]["number"]
            gh = GitHubClient()
            files = await gh.get_pr_files(owner, name, number)
            review, model = await review_pull_request(owner, name, number, files)
            await gh.post_pr_comment(owner, name, number, f"## Re-review (`{model}`)\n\n{review}")
            return {"ok": True, "rereviewed": True}
        return {"ok": True, "skipped": "no command"}

    return {"ok": True, "event": event}
