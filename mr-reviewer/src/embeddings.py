import asyncio
import logging

import tiktoken
from openai import AsyncOpenAI, RateLimitError

from src.config import settings

logger = logging.getLogger(__name__)

client = AsyncOpenAI(
    base_url=f"{settings.litellm_url.rstrip('/')}/v1",
    api_key=settings.litellm_api_key or "sk-placeholder",
)
tokenizer = tiktoken.get_encoding("cl100k_base")

CHUNK_SIZE = 500
CHUNK_OVERLAP = 50
EMBED_TOKEN_BUDGET = 8_000  # stay under Titan input limits
_MAX_RETRIES = 2  # fail fast under Bedrock throttle so chat review can still run


def chunk_text(text: str, file_path: str) -> list[dict]:
    tokens = tokenizer.encode(text)
    chunks: list[dict] = []
    start = 0
    idx = 0
    while start < len(tokens):
        end = min(start + CHUNK_SIZE, len(tokens))
        chunks.append(
            {
                "file_path": file_path,
                "chunk_index": idx,
                "content": tokenizer.decode(tokens[start:end]),
            }
        )
        start = end - CHUNK_OVERLAP if end < len(tokens) else end
        idx += 1
    return chunks


async def _embeddings_create(input_data):
    delay = 2.0
    last_exc: Exception | None = None
    for attempt in range(1, _MAX_RETRIES + 1):
        try:
            return await client.embeddings.create(
                model=settings.embedding_model,
                input=input_data,
            )
        except RateLimitError as exc:
            last_exc = exc
            logger.warning(
                "Bedrock embedding rate-limited (attempt %s/%s); sleeping %.0fs",
                attempt,
                _MAX_RETRIES,
                delay,
            )
            await asyncio.sleep(delay)
            delay = min(delay * 2, 30.0)
    assert last_exc is not None
    raise last_exc


async def generate_embedding(text: str) -> list[float]:
    resp = await _embeddings_create(text)
    return resp.data[0].embedding


async def generate_embeddings_batch(texts: list[str]) -> list[list[float]]:
    # Smaller batches reduce Titan RPM pressure on POC accounts
    if len(texts) <= 4:
        resp = await _embeddings_create(texts)
        return [d.embedding for d in resp.data]
    out: list[list[float]] = []
    for i in range(0, len(texts), 4):
        batch = texts[i : i + 4]
        resp = await _embeddings_create(batch)
        out.extend(d.embedding for d in resp.data)
        if i + 4 < len(texts):
            await asyncio.sleep(1.0)
    return out
