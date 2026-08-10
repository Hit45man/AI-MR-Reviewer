"""GitHub REST client (cloud or GHES). Replaces Horizon's GitLab client."""
from __future__ import annotations

import base64
import logging
from typing import Any

import httpx

from src.config import settings

logger = logging.getLogger(__name__)


class GitHubClient:
    def __init__(self) -> None:
        self.base = settings.github_api_url.rstrip("/")
        self.headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Authorization": f"Bearer {settings.github_token}",
        }

    async def get_pr_files(self, owner: str, repo: str, number: int) -> list[dict[str, Any]]:
        files: list[dict[str, Any]] = []
        page = 1
        async with httpx.AsyncClient(timeout=60) as client:
            while True:
                r = await client.get(
                    f"{self.base}/repos/{owner}/{repo}/pulls/{number}/files",
                    headers=self.headers,
                    params={"per_page": 100, "page": page},
                )
                r.raise_for_status()
                batch = r.json()
                if not batch:
                    break
                files.extend(batch)
                page += 1
        return files

    async def get_file_content(self, owner: str, repo: str, path: str, ref: str) -> str:
        async with httpx.AsyncClient(timeout=60) as client:
            r = await client.get(
                f"{self.base}/repos/{owner}/{repo}/contents/{path}",
                headers=self.headers,
                params={"ref": ref},
            )
            r.raise_for_status()
            data = r.json()
            if data.get("encoding") == "base64":
                return base64.b64decode(data["content"]).decode("utf-8", errors="replace")
            return data.get("content") or ""

    async def post_pr_comment(self, owner: str, repo: str, number: int, body: str) -> None:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(
                f"{self.base}/repos/{owner}/{repo}/issues/{number}/comments",
                headers=self.headers,
                json={"body": body},
            )
            r.raise_for_status()

    async def list_repo_tree(self, owner: str, repo: str, ref: str = "HEAD") -> list[dict[str, Any]]:
        async with httpx.AsyncClient(timeout=120) as client:
            r = await client.get(
                f"{self.base}/repos/{owner}/{repo}/git/trees/{ref}",
                headers=self.headers,
                params={"recursive": "1"},
            )
            r.raise_for_status()
            return r.json().get("tree", [])
