"""Application configuration via environment variables."""

from functools import lru_cache

from pydantic import model_validator
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
    redis_url: str = "redis://:changeme_dev@localhost:6379/0"

    # JWT — no defaults for secrets; app fails fast if missing
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 15
    max_concurrent_sessions: int = 5

    # Plaid — per-environment secrets; resolved via plaid_active_secret property
    plaid_client_id: str = ""
    plaid_sandbox_secret: str = ""
    plaid_production_secret: str = ""
    plaid_env: str = "sandbox"
    plaid_encryption_key: str = ""  # Fernet key for encrypting Plaid tokens at rest
    plaid_redirect_uri: str = ""  # HTTPS Universal Link for OAuth institutions
    plaid_webhook_url: str = ""  # URL for Plaid webhook notifications

    @property
    def plaid_active_secret(self) -> str:
        """Return the Plaid secret matching the current environment."""
        if self.plaid_env in ("development", "production"):
            return self.plaid_production_secret
        return self.plaid_sandbox_secret

    # Claude AI — required in production
    claude_api_key: str = ""

    # AI privacy — replace account/institution/debt names with generic labels before
    # sending financial context to the Claude API (balances and rates are kept intact)
    anonymize_pii_for_ai: bool = False

    # Environment — controls feature availability and security enforcement
    environment: str = "development"  # "development", "test", "production"

    # Dev — skip JWT signature verification (for local dev without Apple JWKS)
    dev_skip_auth_verification: bool = False

    # CORS
    cors_origins: list[str] = ["http://localhost:3000"]

    @model_validator(mode="after")
    def _validate_plaid_encryption_key(self) -> "Settings":
        """Require plaid_encryption_key when Plaid is configured."""
        if self.plaid_client_id and not self.plaid_encryption_key:
            raise ValueError(
                "PLAID_ENCRYPTION_KEY must be set when PLAID_CLIENT_ID is configured. "
                "Generate one with: python -c \"from cryptography.fernet import Fernet; "
                "print(Fernet.generate_key().decode())\""
            )
        return self

    @model_validator(mode="after")
    def _validate_dev_flags(self) -> "Settings":
        """Prevent dev-only flags from being enabled in production."""
        if self.dev_skip_auth_verification and self.environment == "production":
            raise ValueError(
                "DEV_SKIP_AUTH_VERIFICATION cannot be enabled in production. "
                "Set ENVIRONMENT to 'development' or 'test' to use this flag."
            )
        return self


@lru_cache
def get_settings() -> Settings:
    """Return cached application settings singleton."""
    return Settings()
