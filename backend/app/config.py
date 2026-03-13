"""Application configuration via environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables or .env file."""

    model_config = SettingsConfigDict(
        env_file=(".env", ".env.local", "../../.env.local"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    database_url: str = "postgresql+asyncpg://wealth:wealth@localhost:5432/wealth_manager"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # JWT — no defaults for secrets; app fails fast if missing
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    # Plaid — per-environment secrets; resolved via plaid_active_secret property
    plaid_client_id: str = ""
    plaid_sandbox_secret: str = ""
    plaid_production_secret: str = ""
    plaid_env: str = "sandbox"

    @property
    def plaid_active_secret(self) -> str:
        """Return the Plaid secret matching the current environment."""
        if self.plaid_env == "production":
            return self.plaid_production_secret
        return self.plaid_sandbox_secret

    # Claude AI — required in production
    claude_api_key: str = ""

    # CORS
    cors_origins: list[str] = ["http://localhost:3000"]


@lru_cache
def get_settings() -> Settings:
    """Return cached application settings singleton."""
    return Settings()
