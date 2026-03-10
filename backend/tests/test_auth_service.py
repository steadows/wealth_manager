"""Tests for auth_service — JWT create/verify and Apple token decode."""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta
from unittest.mock import patch

import pytest
from jose import jwt

os.environ["JWT_SECRET"] = "test-secret-not-for-production"
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from app.config import get_settings

# Clear cached settings so test env vars take effect
get_settings.cache_clear()

from app.services.auth_service import (
    create_access_token,
    decode_apple_identity_token,
    verify_token,
)


SECRET = "test-secret-not-for-production"
ALGORITHM = "HS256"


class TestCreateAccessToken:
    """Tests for create_access_token."""

    def test_returns_string(self) -> None:
        """Token should be a non-empty string."""
        token = create_access_token(uuid.uuid4())
        assert isinstance(token, str)
        assert len(token) > 0

    def test_token_contains_user_id_sub(self) -> None:
        """Token payload should include the user_id as 'sub'."""
        user_id = uuid.uuid4()
        token = create_access_token(user_id)
        payload = jwt.decode(token, SECRET, algorithms=[ALGORITHM])
        assert payload["sub"] == str(user_id)

    def test_token_contains_exp(self) -> None:
        """Token should have an expiration claim."""
        token = create_access_token(uuid.uuid4())
        payload = jwt.decode(token, SECRET, algorithms=[ALGORITHM])
        assert "exp" in payload

    def test_token_contains_iat(self) -> None:
        """Token should have an issued-at claim."""
        token = create_access_token(uuid.uuid4())
        payload = jwt.decode(token, SECRET, algorithms=[ALGORITHM])
        assert "iat" in payload

    def test_custom_expire_minutes(self) -> None:
        """Token expiration should respect custom expire_minutes."""
        token = create_access_token(uuid.uuid4(), expire_minutes=5)
        payload = jwt.decode(token, SECRET, algorithms=[ALGORITHM])
        iat = datetime.fromtimestamp(payload["iat"], tz=UTC)
        exp = datetime.fromtimestamp(payload["exp"], tz=UTC)
        delta = exp - iat
        assert timedelta(minutes=4) < delta <= timedelta(minutes=6)


class TestVerifyToken:
    """Tests for verify_token."""

    def test_valid_token_returns_user_id(self) -> None:
        """verify_token should return the original user_id for a valid token."""
        user_id = uuid.uuid4()
        token = create_access_token(user_id)
        result = verify_token(token)
        assert result == user_id

    def test_expired_token_raises(self) -> None:
        """verify_token should raise ValueError for an expired token."""
        user_id = uuid.uuid4()
        payload = {
            "sub": str(user_id),
            "exp": datetime.now(UTC) - timedelta(hours=1),
            "iat": datetime.now(UTC) - timedelta(hours=2),
        }
        token = jwt.encode(payload, SECRET, algorithm=ALGORITHM)
        with pytest.raises(ValueError, match="expired|invalid"):
            verify_token(token)

    def test_invalid_token_raises(self) -> None:
        """verify_token should raise ValueError for a malformed token."""
        with pytest.raises(ValueError, match="expired|invalid"):
            verify_token("not.a.valid.token")

    def test_wrong_secret_raises(self) -> None:
        """verify_token should raise ValueError if token was signed with different secret."""
        payload = {
            "sub": str(uuid.uuid4()),
            "exp": datetime.now(UTC) + timedelta(hours=1),
            "iat": datetime.now(UTC),
        }
        token = jwt.encode(payload, "wrong-secret", algorithm=ALGORITHM)
        with pytest.raises(ValueError, match="expired|invalid"):
            verify_token(token)

    def test_missing_sub_raises(self) -> None:
        """verify_token should raise ValueError if 'sub' claim is missing."""
        payload = {
            "exp": datetime.now(UTC) + timedelta(hours=1),
            "iat": datetime.now(UTC),
        }
        token = jwt.encode(payload, SECRET, algorithm=ALGORITHM)
        with pytest.raises(ValueError, match="expired|invalid"):
            verify_token(token)


class TestDecodeAppleIdentityToken:
    """Tests for decode_apple_identity_token (sandbox mode)."""

    def test_sandbox_extracts_sub(self) -> None:
        """In sandbox mode, should extract sub claim from unverified token."""
        payload = {"sub": "apple-user-001", "email": "test@example.com"}
        token = jwt.encode(payload, "any-key", algorithm="HS256")
        result = decode_apple_identity_token(token)
        assert result["sub"] == "apple-user-001"
        assert result["email"] == "test@example.com"

    def test_sandbox_missing_sub_raises(self) -> None:
        """Should raise ValueError if token has no sub claim."""
        payload = {"email": "test@example.com"}
        token = jwt.encode(payload, "any-key", algorithm="HS256")
        with pytest.raises(ValueError, match="sub"):
            decode_apple_identity_token(token)

    def test_malformed_token_raises(self) -> None:
        """Should raise ValueError for a completely invalid token."""
        with pytest.raises(ValueError):
            decode_apple_identity_token("not-a-jwt")
