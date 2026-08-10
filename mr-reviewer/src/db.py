from sqlalchemy import Text, Integer, String, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from src.config import settings

# asyncpg URL
_db_url = settings.database_url.replace("postgresql://", "postgresql+asyncpg://", 1)


class Base(DeclarativeBase):
    pass


class Repo(Base):
    __tablename__ = "repos"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(255), unique=True)  # owner/repo
    default_branch: Mapped[str] = mapped_column(String(128), default="main")


class FileChunk(Base):
    __tablename__ = "file_chunks"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    repo_id: Mapped[int] = mapped_column(ForeignKey("repos.id"))
    file_path: Mapped[str] = mapped_column(String(1024))
    chunk_index: Mapped[int] = mapped_column(Integer)
    content: Mapped[str] = mapped_column(Text)
    # embedding column created via raw SQL: vector(1024) for Titan v2


class RepoInstructions(Base):
    __tablename__ = "repo_instructions"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    repo: Mapped[str] = mapped_column(String(255), unique=True)
    content: Mapped[str] = mapped_column(Text, default="")
    updated_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())


engine = create_async_engine(_db_url or "postgresql+asyncpg://localhost/mr_reviewer", pool_pre_ping=True)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

INIT_SQL = """
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS repos (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  default_branch VARCHAR(128) DEFAULT 'main'
);
CREATE TABLE IF NOT EXISTS file_chunks (
  id SERIAL PRIMARY KEY,
  repo_id INT REFERENCES repos(id) ON DELETE CASCADE,
  file_path VARCHAR(1024) NOT NULL,
  chunk_index INT NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1024)
);
CREATE TABLE IF NOT EXISTS repo_instructions (
  id SERIAL PRIMARY KEY,
  repo VARCHAR(255) UNIQUE NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS file_chunks_embedding_idx
  ON file_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
"""
