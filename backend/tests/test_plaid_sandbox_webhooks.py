"""Integration tests for Plaid sandbox webhook and reset-login endpoints.

These tests hit the real Plaid sandbox API. They require valid
PLAID_CLIENT_ID and PLAID_SANDBOX_SECRET environment variables.

Run with: pytest tests/test_plaid_sandbox_webhooks.py -v -m integration
"""

from __future__ import annotations

import os

import pytest

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from plaid.exceptions import ApiException

from app.services.plaid_service import PlaidService


@pytest.fixture(scope="module")
def plaid_service() -> PlaidService:
    """Create a PlaidService configured for the sandbox environment."""
    return PlaidService()


@pytest.fixture(scope="module")
def sandbox_access_token(plaid_service: PlaidService) -> str:
    """Create a sandbox item with a webhook URL and return its access token.

    Module-scoped so the token is reused across tests in this file.
    A webhook URL is required for fire_sandbox_webhook to succeed.
    """
    public_token = plaid_service.create_sandbox_public_token(
        institution_id="ins_109508",
        initial_products=["transactions"],
        webhook="https://example.com/webhook",
    )
    access_token, _item_id = plaid_service.exchange_public_token(public_token)
    return access_token


@pytest.mark.integration
class TestFireSandboxWebhook:
    """P.6 — Test SYNC_UPDATES_AVAILABLE webhook fires successfully."""

    def test_fire_sync_updates_available(
        self,
        plaid_service: PlaidService,
        sandbox_access_token: str,
    ) -> None:
        """Firing SYNC_UPDATES_AVAILABLE webhook should succeed."""
        result = plaid_service.fire_sandbox_webhook(
            access_token=sandbox_access_token,
            webhook_code="SYNC_UPDATES_AVAILABLE",
        )
        assert result["webhook_fired"] is True

    def test_fire_webhook_returns_bool_true(
        self,
        plaid_service: PlaidService,
        sandbox_access_token: str,
    ) -> None:
        """webhook_fired value should be a boolean True."""
        result = plaid_service.fire_sandbox_webhook(
            access_token=sandbox_access_token,
            webhook_code="SYNC_UPDATES_AVAILABLE",
        )
        assert isinstance(result["webhook_fired"], bool)
        assert result["webhook_fired"] is True

    def test_fire_webhook_default_code(
        self,
        plaid_service: PlaidService,
        sandbox_access_token: str,
    ) -> None:
        """Firing webhook with default code param should use SYNC_UPDATES_AVAILABLE."""
        result = plaid_service.fire_sandbox_webhook(
            access_token=sandbox_access_token,
        )
        assert result["webhook_fired"] is True


@pytest.mark.integration
class TestResetSandboxLogin:
    """P.7 — Test ITEM_LOGIN_REQUIRED via reset_login."""

    def test_reset_login_succeeds(
        self,
        plaid_service: PlaidService,
        sandbox_access_token: str,
    ) -> None:
        """Resetting sandbox login should return reset_login=True."""
        result = plaid_service.reset_sandbox_login(
            access_token=sandbox_access_token,
        )
        assert result["reset_login"] is True


@pytest.mark.integration
class TestSandboxWebhookErrors:
    """P.8 — Error handling tests for sandbox webhook endpoints."""

    def test_fire_webhook_invalid_access_token(
        self,
        plaid_service: PlaidService,
    ) -> None:
        """Firing webhook with invalid access token should raise ApiException."""
        with pytest.raises(ApiException) as exc_info:
            plaid_service.fire_sandbox_webhook(
                access_token="access-sandbox-invalid-token-999",
                webhook_code="SYNC_UPDATES_AVAILABLE",
            )
        assert exc_info.value.status in (400, 401, 404)

    def test_fire_webhook_invalid_webhook_code(
        self,
        plaid_service: PlaidService,
        sandbox_access_token: str,
    ) -> None:
        """Firing webhook with an invalid webhook_code should raise an error."""
        with pytest.raises((ApiException, ValueError)):
            plaid_service.fire_sandbox_webhook(
                access_token=sandbox_access_token,
                webhook_code="TOTALLY_INVALID_CODE",
            )

    def test_reset_login_invalid_access_token(
        self,
        plaid_service: PlaidService,
    ) -> None:
        """Resetting login with invalid access token should raise ApiException."""
        with pytest.raises(ApiException) as exc_info:
            plaid_service.reset_sandbox_login(
                access_token="access-sandbox-invalid-token-999",
            )
        assert exc_info.value.status in (400, 401, 404)

    def test_fire_webhook_with_bad_credentials(self) -> None:
        """PlaidService with bad credentials should fail on API call, not init."""
        bad_service = PlaidService(
            client_id="bad-client-id",
            secret="bad-secret",
            environment="sandbox",
        )
        # Constructor succeeds — API call fails
        with pytest.raises(ApiException) as exc_info:
            public_token = "access-sandbox-fake"
            bad_service.fire_sandbox_webhook(
                access_token=public_token,
                webhook_code="SYNC_UPDATES_AVAILABLE",
            )
        assert exc_info.value.status in (400, 401, 403)
