"""Tests for encryption utility and Plaid token encryption integration."""

from __future__ import annotations

import os
import uuid
from decimal import Decimal
from unittest.mock import MagicMock, patch

import pytest
from cryptography.fernet import Fernet

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault(
    "PLAID_ENCRYPTION_KEY", "PrpkpI4BgxXvJt05Iqq2gIycYUVVr0L2Rz--cIw-nzo="
)

from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.dependencies import get_current_user, get_db
from app.main import create_app
from app.models.account import Account
from app.services.auth_service import create_access_token
from app.services.plaid_service import get_plaid_service
from app.utils.encryption import InvalidToken, decrypt_value, encrypt_value

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")
TEST_FERNET_KEY = Fernet.generate_key().decode()


@pytest.fixture
def auth_headers() -> dict[str, str]:
    """Return Authorization headers with a valid JWT for TEST_USER_ID."""
    token = create_access_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


# --- Unit tests for encrypt/decrypt ---


class TestEncryptDecrypt:
    """Unit tests for the encryption utility functions."""

    def test_roundtrip(self) -> None:
        """Encrypting then decrypting returns original value."""
        plaintext = "access-sandbox-abc123def456"
        ciphertext = encrypt_value(plaintext, TEST_FERNET_KEY)
        assert ciphertext != plaintext
        assert decrypt_value(ciphertext, TEST_FERNET_KEY) == plaintext

    def test_different_keys_fail(self) -> None:
        """Decrypting with a different key raises InvalidToken."""
        plaintext = "access-sandbox-secret"
        ciphertext = encrypt_value(plaintext, TEST_FERNET_KEY)
        other_key = Fernet.generate_key().decode()
        with pytest.raises(InvalidToken):
            decrypt_value(ciphertext, other_key)

    def test_corrupted_ciphertext_fails(self) -> None:
        """Corrupted ciphertext raises InvalidToken."""
        with pytest.raises(Exception):
            decrypt_value("not-a-valid-ciphertext", TEST_FERNET_KEY)

    def test_empty_string_roundtrip(self) -> None:
        """Empty string encrypts and decrypts correctly."""
        ciphertext = encrypt_value("", TEST_FERNET_KEY)
        assert decrypt_value(ciphertext, TEST_FERNET_KEY) == ""

    def test_ciphertext_is_different_each_time(self) -> None:
        """Fernet uses a timestamp+IV, so same plaintext produces different ciphertext."""
        plaintext = "access-sandbox-abc123"
        ct1 = encrypt_value(plaintext, TEST_FERNET_KEY)
        ct2 = encrypt_value(plaintext, TEST_FERNET_KEY)
        assert ct1 != ct2  # non-deterministic
        assert decrypt_value(ct1, TEST_FERNET_KEY) == plaintext
        assert decrypt_value(ct2, TEST_FERNET_KEY) == plaintext


# --- Integration test: exchange-token stores encrypted token ---


@pytest.fixture
async def encryption_engine():
    """Create an async SQLite engine for encryption tests."""
    eng = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()


@pytest.fixture
async def encryption_client(encryption_engine) -> AsyncClient:
    """Yield an httpx AsyncClient wired to the test app with encryption key set."""
    factory = async_sessionmaker(
        bind=encryption_engine, class_=AsyncSession, expire_on_commit=False
    )

    async def override_get_db():
        async with factory() as sess:
            try:
                yield sess
                await sess.commit()
            except Exception:
                await sess.rollback()
                raise

    async def override_get_current_user() -> uuid.UUID:
        return TEST_USER_ID

    mock_plaid = MagicMock()
    mock_plaid.exchange_public_token.return_value = (
        "access-sandbox-plaintext-token",
        "item-sandbox-123",
    )
    mock_plaid.get_accounts.return_value = [
        {
            "account_id": "plaid-acct-001",
            "name": "Checking",
            "official_name": "Gold Checking",
            "type": "depository",
            "subtype": "checking",
            "balances": {"current": 1000.50, "available": 900.00},
        }
    ]

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user
    app.dependency_overrides[get_plaid_service] = lambda: mock_plaid

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_exchange_token_stores_encrypted_token(
    encryption_client: AsyncClient, encryption_engine, auth_headers: dict
) -> None:
    """The exchange-token endpoint must store an encrypted (not plaintext) access token."""
    with patch("app.routers.plaid.get_settings") as mock_settings:
        settings = MagicMock()
        settings.plaid_encryption_key = TEST_FERNET_KEY
        settings.plaid_env = "sandbox"
        mock_settings.return_value = settings

        resp = await encryption_client.post(
            "/api/v1/plaid/exchange-token",
            json={"public_token": "public-sandbox-test"},
            headers=auth_headers,
        )

    assert resp.status_code == 200
    data = resp.json()
    assert len(data["accounts"]) == 1

    # Read the raw DB value to confirm it's NOT the plaintext token
    factory = async_sessionmaker(
        bind=encryption_engine, class_=AsyncSession, expire_on_commit=False
    )
    async with factory() as sess:
        result = await sess.execute(select(Account))
        account = result.scalars().first()
        assert account is not None
        # The stored value must NOT be the plaintext token
        assert account.plaid_access_token != "access-sandbox-plaintext-token"
        # But decrypting it must yield the original
        decrypted = decrypt_value(account.plaid_access_token, TEST_FERNET_KEY)
        assert decrypted == "access-sandbox-plaintext-token"


# --- Config validation test ---


class TestConfigValidation:
    """Test that config validates encryption key when Plaid is configured."""

    def test_plaid_configured_without_encryption_key_raises(self) -> None:
        """Setting plaid_client_id without plaid_encryption_key must raise."""
        from pydantic import ValidationError

        from app.config import Settings

        with pytest.raises(ValidationError, match="PLAID_ENCRYPTION_KEY"):
            Settings(
                jwt_secret="test",
                plaid_client_id="some-client-id",
                plaid_encryption_key="",
                _env_file=None,
            )

    def test_no_plaid_configured_passes_without_encryption_key(self) -> None:
        """If plaid_client_id is empty, encryption key is not required."""
        from app.config import Settings

        settings = Settings(
            jwt_secret="test",
            plaid_client_id="",
            plaid_encryption_key="",
            _env_file=None,
        )
        assert settings.plaid_encryption_key == ""
