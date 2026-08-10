from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # LiteLLM → Amazon Bedrock only (aliases from litellm/proxy_config.yaml)
    litellm_url: str = "http://litellm.mr-reviewer-dev.local:4000"
    litellm_api_key: str = ""
    primary_model: str = "nova-micro"
    fallback_model: str = "nova-lite"
    embedding_model: str = "titan-embed-v2"

    # GitHub (cloud or GHES)
    github_api_url: str = "https://api.github.com"
    github_token: str = ""  # PAT for POC; prefer GitHub App in prod
    github_app_id: str = ""
    github_app_private_key: str = ""
    github_webhook_secret: str = ""
    watched_repos: str = ""
    bot_login: str = "mr-reviewer-bot"  # skip own comments

    database_url: str = ""
    max_diff_size: int = 80_000
    top_k_context: int = 10

    @property
    def repo_list(self) -> list[str]:
        return [r.strip() for r in self.watched_repos.split(",") if r.strip()]

    class Config:
        env_prefix = ""
        case_sensitive = False


settings = Settings()
