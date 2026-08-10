import logging

from fastapi import FastAPI
from sqlalchemy import text

from src.config import settings
from src.db import INIT_SQL, engine
from src.indexer import run_full_index
from src.webhook import router as webhook_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="AWS MR Reviewer (GitHub + Bedrock)", version="0.1.0")
app.include_router(webhook_router)


@app.on_event("startup")
async def startup() -> None:
    if not settings.database_url:
        logger.warning("DATABASE_URL empty — skipping schema init")
        return
    async with engine.begin() as conn:
        for stmt in INIT_SQL.split(";"):
            s = stmt.strip()
            if s:
                try:
                    await conn.execute(text(s))
                except Exception as exc:
                    logger.warning("init sql note: %s", exc)


@app.get("/healthz")
async def healthz():
    return {
        "status": "ok",
        "scm": "github",
        "llm": "bedrock-via-litellm",
        "primary_model": settings.primary_model,
        "embedding_model": settings.embedding_model,
    }


@app.post("/index")
async def index():
    result = await run_full_index()
    return {"ok": True, **result}


@app.get("/repos")
async def repos():
    return {"watched": settings.repo_list}
