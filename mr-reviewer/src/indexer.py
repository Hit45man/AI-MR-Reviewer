"""Full-repo indexer for RAG (GitHub Contents / Git Tree API)."""
from __future__ import annotations

import logging

from sqlalchemy import delete, select, text

from src.config import settings
from src.db import FileChunk, Repo, RepoInstructions, async_session
from src.embeddings import chunk_text, generate_embeddings_batch, tokenizer, EMBED_TOKEN_BUDGET
from src.github_client import GitHubClient

logger = logging.getLogger(__name__)

INDEXABLE = {".tf", ".tfvars", ".yaml", ".yml", ".md", ".json", ".hcl", ".toml", ".py", ".sh"}
MAX_FILE = 50_000


def _batch_by_tokens(items: list[dict]):
    cur, cur_tokens = [], 0
    for c in items:
        t = len(tokenizer.encode(c["content"]))
        if cur and cur_tokens + t > EMBED_TOKEN_BUDGET:
            yield cur
            cur, cur_tokens = [], 0
        cur.append(c)
        cur_tokens += t
    if cur:
        yield cur


async def run_full_index() -> dict:
    gh = GitHubClient()
    indexed_files = 0
    indexed_chunks = 0

    for full in settings.repo_list:
        owner, repo = full.split("/", 1)
        logger.info("indexing %s", full)
        tree = await gh.list_repo_tree(owner, repo, ref="HEAD")
        async with async_session() as session:
            existing = await session.execute(select(Repo).where(Repo.name == full))
            repo_row = existing.scalar_one_or_none()
            if not repo_row:
                repo_row = Repo(name=full)
                session.add(repo_row)
                await session.flush()
            await session.execute(delete(FileChunk).where(FileChunk.repo_id == repo_row.id))

            pending: list[dict] = []
            for node in tree:
                if node.get("type") != "blob":
                    continue
                path = node["path"]
                if not any(path.endswith(ext) for ext in INDEXABLE):
                    continue
                if node.get("size", 0) > MAX_FILE:
                    continue
                try:
                    content = await gh.get_file_content(owner, repo, path, ref="HEAD")
                except Exception as exc:
                    logger.warning("skip %s: %s", path, exc)
                    continue
                if path.endswith("instructions.md") or path == "instructions.md":
                    session.merge(RepoInstructions(repo=full, content=content))
                pending.extend(chunk_text(content, path))
                indexed_files += 1

            for batch in _batch_by_tokens(pending):
                vectors = await generate_embeddings_batch([c["content"] for c in batch])
                for chunk, vec in zip(batch, vectors):
                    # insert with raw SQL for vector type
                    await session.execute(
                        text(
                            """
                            INSERT INTO file_chunks (repo_id, file_path, chunk_index, content, embedding)
                            VALUES (:repo_id, :path, :idx, :content, :emb::vector)
                            """
                        ),
                        {
                            "repo_id": repo_row.id,
                            "path": chunk["file_path"],
                            "idx": chunk["chunk_index"],
                            "content": chunk["content"],
                            "emb": "[" + ",".join(str(x) for x in vec) + "]",
                        },
                    )
                    indexed_chunks += 1
            await session.commit()

    return {"files": indexed_files, "chunks": indexed_chunks, "repos": settings.repo_list}
