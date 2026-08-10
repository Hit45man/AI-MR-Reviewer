import logging
from pathlib import Path

from sqlalchemy import select, text

from src.config import settings
from src.db import async_session, FileChunk, Repo, RepoInstructions
from src.embeddings import generate_embedding

logger = logging.getLogger(__name__)


async def find_relevant_context(query: str, repo_name: str | None = None) -> list[dict]:
    try:
        embedding = await generate_embedding(query)
    except Exception as exc:
        # POC: Bedrock Titan RPM limits should not fail the whole review
        logger.warning("RAG embedding failed (%s); continuing without vector context", exc)
        return []

    embedding_str = "[" + ",".join(str(x) for x in embedding) + "]"

    async with async_session() as session:
        filter_clause = ""
        if repo_name:
            repo = await session.execute(select(Repo).where(Repo.name == repo_name))
            repo_obj = repo.scalar_one_or_none()
            if not repo_obj:
                return []
            filter_clause = f"AND fc.repo_id = {repo_obj.id}"

        result = await session.execute(
            text(
                f"""
                SELECT fc.file_path, fc.content,
                       1 - (fc.embedding <=> '{embedding_str}'::vector) AS similarity
                FROM file_chunks fc
                WHERE fc.embedding IS NOT NULL
                {filter_clause}
                ORDER BY fc.embedding <=> '{embedding_str}'::vector
                LIMIT :limit
                """
            ),
            {"limit": settings.top_k_context},
        )
        return [
            {"file_path": row.file_path, "content": row.content, "similarity": row.similarity}
            for row in result
        ]


async def get_repo_instructions(repo_name: str) -> str:
    async with async_session() as session:
        result = await session.execute(
            select(RepoInstructions).where(RepoInstructions.repo == repo_name)
        )
        row = result.scalar_one_or_none()
        return row.content if row else ""


async def get_standards_blob() -> str:
    """Load platform standards from DB index, else ship-with-container docs as fallback."""
    paths = [
        "docs/naming-standard.md",
        "docs/platform-standards.md",
        "Documentation/Resource-naming-standard.md",
    ]
    async with async_session() as session:
        result = await session.execute(
            select(FileChunk.file_path, FileChunk.content, FileChunk.chunk_index).where(
                FileChunk.file_path.in_(paths)
            )
        )
        rows = result.all()
        by_path: dict[str, list[tuple[int, str]]] = {p: [] for p in paths}
        for r in rows:
            by_path[r.file_path].append((r.chunk_index, r.content))
        parts = []
        for path in paths:
            chunks = sorted(by_path[path], key=lambda x: x[0])
            if chunks:
                parts.append(f"--- {path} ---\n" + "\n".join(c for _, c in chunks))
        if parts:
            return "\n\n".join(parts)

    # Fallback when /index has not completed (common under Bedrock embedding throttle)
    root = Path(__file__).resolve().parent.parent  # /app in container
    local_parts = []
    for rel in ("docs/naming-standard.md", "docs/platform-standards.md"):
        p = root / rel
        if p.is_file():
            local_parts.append(f"--- {rel} ---\n{p.read_text(encoding='utf-8')}")
    return "\n\n".join(local_parts)
