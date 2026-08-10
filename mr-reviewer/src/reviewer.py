import logging
from pathlib import Path

from openai import AsyncOpenAI

from src.config import settings
from src.context import find_relevant_context, get_repo_instructions, get_standards_blob

logger = logging.getLogger(__name__)

client = AsyncOpenAI(
    base_url=f"{settings.litellm_url.rstrip('/')}/v1",
    api_key=settings.litellm_api_key or "sk-placeholder",
)
PROMPTS = Path(__file__).resolve().parent.parent / "prompts"


def _load(name: str) -> str:
    return (PROMPTS / name).read_text(encoding="utf-8")


async def _call_model(model: str, system: str, user: str):
    return await client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        max_tokens=4096,
        temperature=0.1,
    )


def build_diff_text(files: list[dict]) -> str:
    """GitHub PR files payload → unified-ish text for the LLM."""
    parts: list[str] = []
    budget = settings.max_diff_size
    used = 0
    for f in files:
        patch = f.get("patch") or ""
        header = f"--- a/{f.get('filename')} ({f.get('status')})\n"
        block = header + patch
        if used + len(block) > budget:
            parts.append(header + patch[: max(0, budget - used)] + "\n... (truncated)")
            break
        parts.append(block)
        used += len(block)
    return "\n\n".join(parts)


async def review_pull_request(owner: str, repo: str, number: int, files: list[dict]) -> tuple[str, str]:
    repo_full = f"{owner}/{repo}"
    diff_text = build_diff_text(files)
    chunks = await find_relevant_context(diff_text, repo_name=repo_full)
    context_text = "\n\n".join(
        f"--- {c['file_path']} (sim={c.get('similarity', 0):.2f}) ---\n{c['content']}" for c in chunks
    )
    instructions = await get_repo_instructions(repo_full)
    standards = await get_standards_blob()

    system = _load("review_system.md") + "\n\n# Platform standards\n\n" + (standards or "(index docs/naming-standard.md and docs/platform-standards.md)")
    user = _load("review_diff.md").format(
        repo=repo_full,
        pr=number,
        instructions=instructions or "(none)",
        context=context_text or "(no RAG hits yet — run /index)",
        diff=diff_text or "(empty diff)",
    )

    model = settings.primary_model
    try:
        resp = await _call_model(model, system, user)
    except Exception as exc:
        logger.warning("Primary model %s failed: %s — falling back to %s", model, exc, settings.fallback_model)
        model = settings.fallback_model
        resp = await _call_model(model, system, user)

    text = resp.choices[0].message.content or ""
    usage = resp.usage
    logger.info(
        "review tokens prompt=%s completion=%s model=%s repo=%s#%s",
        getattr(usage, "prompt_tokens", None),
        getattr(usage, "completion_tokens", None),
        model,
        repo_full,
        number,
    )
    return text, model
