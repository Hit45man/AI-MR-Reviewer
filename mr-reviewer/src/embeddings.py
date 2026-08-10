import tiktoken
from openai import AsyncOpenAI

from src.config import settings

client = AsyncOpenAI(
    base_url=f"{settings.litellm_url.rstrip('/')}/v1",
    api_key=settings.litellm_api_key or "sk-placeholder",
)
tokenizer = tiktoken.get_encoding("cl100k_base")

CHUNK_SIZE = 500
CHUNK_OVERLAP = 50
EMBED_TOKEN_BUDGET = 8_000  # stay under Titan input limits


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


async def generate_embedding(text: str) -> list[float]:
    resp = await client.embeddings.create(
        model=settings.embedding_model,
        input=text,
    )
    return resp.data[0].embedding


async def generate_embeddings_batch(texts: list[str]) -> list[list[float]]:
    resp = await client.embeddings.create(
        model=settings.embedding_model,
        input=texts,
    )
    return [d.embedding for d in resp.data]
