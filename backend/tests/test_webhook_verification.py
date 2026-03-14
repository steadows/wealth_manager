"""Tests for Plaid webhook signature verification.

Covers:
- Valid signature: webhook is processed
- Missing signature in production: rejected with 401
- Missing signature in sandbox: allowed with warning
- Invalid signature: rejected with 401
- Body hash mismatch: rejected with 401
"""

from __future__ import annotations

import hashlib
import json
import os
import time
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

import jwt as pyjwt
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from app.services.plaid_service import PlaidService, _jwk_cache


def _make_ec_key_pair() -> tuple[ec.EllipticCurvePrivateKey, dict]:
    """Generate an EC P-256 key pair for testing.

    Returns:
        Tuple of (private_key, public_jwk_dict).
    """
    private_key = ec.generate_private_key(ec.SECP256R1())
    # Build JWK from public key using PyJWT's algorithm helper
    algo = pyjwt.algorithms.ECAlgorithm(pyjwt.algorithms.ECAlgorithm.SHA256)
    public_jwk = algo.to_jwk(private_key.public_key(), as_dict=True)
    public_jwk["kid"] = "test-key-id-001"
    public_jwk["alg"] = "ES256"
    public_jwk["use"] = "sig"
    return private_key, public_jwk


def _sign_webhook_body(
    body: bytes,
    private_key: ec.EllipticCurvePrivateKey,
    kid: str = "test-key-id-001",
) -> str:
    """Create a Plaid-Verification JWT for the given body.

    Args:
        body: Raw request body bytes.
        private_key: The EC private key to sign with.
        kid: The key ID to include in the JWT header.

    Returns:
        A signed JWT string.
    """
    body_hash = hashlib.sha256(body).hexdigest()
    claims = {
        "request_body_sha256": body_hash,
        "iat": int(time.time()),
    }
    token = pyjwt.encode(
        claims,
        private_key,
        algorithm="ES256",
        headers={"kid": kid},
    )
    return token


class TestVerifyWebhookBody:
    """Unit tests for PlaidService.verify_webhook_body."""

    def setup_method(self) -> None:
        """Set up test fixtures."""
        _jwk_cache.clear()
        self.private_key, self.public_jwk = _make_ec_key_pair()

    def teardown_method(self) -> None:
        """Clean up JWK cache."""
        _jwk_cache.clear()

    def test_valid_signature_returns_true(self) -> None:
        """A correctly signed webhook body should verify successfully."""
        body = b'{"webhook_type":"TRANSACTIONS","webhook_code":"SYNC_UPDATES_AVAILABLE"}'
        token = _sign_webhook_body(body, self.private_key)

        service = PlaidService.__new__(PlaidService)
        service._client = MagicMock()

        # Mock the verification key fetch
        mock_response = MagicMock()
        mock_key = MagicMock()
        mock_key.to_dict.return_value = self.public_jwk
        mock_response.key = mock_key
        service._client.webhook_verification_key_get.return_value = mock_response

        assert service.verify_webhook_body(body, token) is True

    def test_invalid_signature_raises_value_error(self) -> None:
        """A webhook signed with a different key should fail verification."""
        body = b'{"webhook_type":"TRANSACTIONS"}'
        # Sign with one key
        other_private_key, _other_public_jwk = _make_ec_key_pair()
        token = _sign_webhook_body(body, other_private_key)

        service = PlaidService.__new__(PlaidService)
        service._client = MagicMock()

        # But return a different public key for verification
        mock_response = MagicMock()
        mock_key = MagicMock()
        mock_key.to_dict.return_value = self.public_jwk
        mock_response.key = mock_key
        service._client.webhook_verification_key_get.return_value = mock_response

        with pytest.raises(ValueError, match="JWT verification failed"):
            service.verify_webhook_body(body, token)

    def test_body_hash_mismatch_raises_value_error(self) -> None:
        """A valid JWT with wrong body hash should fail verification."""
        original_body = b'{"original":"body"}'
        tampered_body = b'{"tampered":"body"}'

        # Sign the original body
        token = _sign_webhook_body(original_body, self.private_key)

        service = PlaidService.__new__(PlaidService)
        service._client = MagicMock()

        mock_response = MagicMock()
        mock_key = MagicMock()
        mock_key.to_dict.return_value = self.public_jwk
        mock_response.key = mock_key
        service._client.webhook_verification_key_get.return_value = mock_response

        # Verify with the tampered body
        with pytest.raises(ValueError, match="body hash mismatch"):
            service.verify_webhook_body(tampered_body, token)

    def test_missing_kid_raises_value_error(self) -> None:
        """A JWT without a kid header should fail verification."""
        body = b'{"test":"body"}'
        body_hash = hashlib.sha256(body).hexdigest()
        # Create a JWT without kid in the header
        token = pyjwt.encode(
            {"request_body_sha256": body_hash},
            self.private_key,
            algorithm="ES256",
            # No kid header
        )

        service = PlaidService.__new__(PlaidService)
        service._client = MagicMock()

        with pytest.raises(ValueError, match="Missing kid"):
            service.verify_webhook_body(body, token)

    def test_malformed_jwt_raises_value_error(self) -> None:
        """A completely invalid JWT string should fail verification."""
        service = PlaidService.__new__(PlaidService)
        service._client = MagicMock()

        with pytest.raises(ValueError):
            service.verify_webhook_body(b"body", "not.a.valid.jwt")

    def test_jwk_cache_hit_avoids_api_call(self) -> None:
        """A cached JWK should be reused without calling the Plaid API."""
        body = b'{"cached":"test"}'
        token = _sign_webhook_body(body, self.private_key)

        service = PlaidService.__new__(PlaidService)
        service._client = MagicMock()

        # Pre-populate cache
        _jwk_cache["test-key-id-001"] = (self.public_jwk, time.time())

        assert service.verify_webhook_body(body, token) is True
        # Should not have called the API
        service._client.webhook_verification_key_get.assert_not_called()


@pytest.mark.asyncio
class TestWebhookEndpointVerification:
    """Integration tests for the webhook endpoint signature verification."""

    async def test_missing_header_production_returns_401(self, client: "AsyncClient") -> None:
        """In production mode, a missing Plaid-Verification header returns 401."""
        body = {"webhook_type": "TRANSACTIONS", "webhook_code": "SYNC_UPDATES_AVAILABLE"}

        with patch("app.routers.webhooks.get_settings") as mock_settings:
            settings = MagicMock()
            settings.plaid_env = "production"
            mock_settings.return_value = settings

            response = await client.post(
                "/api/v1/webhooks/plaid",
                content=json.dumps(body),
                headers={"Content-Type": "application/json"},
            )

        assert response.status_code == 401
        assert "Plaid-Verification" in response.json()["detail"]

    async def test_missing_header_sandbox_allowed(self, client: "AsyncClient") -> None:
        """In sandbox mode, a missing Plaid-Verification header is allowed."""
        body = {"webhook_type": "ITEMS", "webhook_code": "PENDING_EXPIRATION"}

        with patch("app.routers.webhooks.get_settings") as mock_settings:
            settings = MagicMock()
            settings.plaid_env = "sandbox"
            mock_settings.return_value = settings

            response = await client.post(
                "/api/v1/webhooks/plaid",
                content=json.dumps(body),
                headers={"Content-Type": "application/json"},
            )

        assert response.status_code == 200
        assert response.json()["status"] == "ignored"

    async def test_invalid_signature_returns_401(self, client: "AsyncClient") -> None:
        """A webhook with an invalid signature should return 401."""
        body = {"webhook_type": "TRANSACTIONS", "webhook_code": "SYNC_UPDATES_AVAILABLE"}

        with patch("app.routers.webhooks.get_settings") as mock_settings:
            settings = MagicMock()
            settings.plaid_env = "production"
            mock_settings.return_value = settings

            response = await client.post(
                "/api/v1/webhooks/plaid",
                content=json.dumps(body),
                headers={
                    "Content-Type": "application/json",
                    "Plaid-Verification": "invalid.jwt.token",
                },
            )

        assert response.status_code == 401
        assert "verification failed" in response.json()["detail"]
