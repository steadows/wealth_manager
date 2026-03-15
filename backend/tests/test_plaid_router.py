"""Tests for plaid router — link-token, exchange-token, sync endpoints."""

from __future__ import annotations

import os
import time
import uuid
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault(
    "PLAID_ENCRYPTION_KEY", "PrpkpI4BgxXvJt05Iqq2gIycYUVVr0L2Rz--cIw-nzo="
)

from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.routers.plaid import _link_token_owners
from app.dependencies import get_current_user, get_db
from app.main import create_app
from app.config import get_settings
from app.models.account import Account
from app.services.auth_service import create_access_token
from app.services.plaid_service import get_plaid_service
from app.utils.encryption import encrypt_value

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")


@pytest.fixture
def auth_headers() -> dict[str, str]:
    """Return Authorization headers with a valid JWT for TEST_USER_ID."""
    token = create_access_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def plaid_engine():
    """Create an async SQLite engine for plaid tests."""
    eng = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()


@pytest.fixture
async def plaid_session(plaid_engine) -> AsyncSession:
    """Yield a test database session."""
    factory = async_sessionmaker(bind=plaid_engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as sess:
        yield sess


@pytest.fixture
def mock_plaid_service() -> MagicMock:
    """Create a mock PlaidService with sensible sync defaults."""
    mock = MagicMock()
    mock.sync_transactions.return_value = {
        "added": [],
        "modified": [],
        "removed": [],
        "next_cursor": "cursor-123",
        "has_more": False,
    }
    return mock


@pytest.fixture
async def plaid_client(plaid_engine, mock_plaid_service: MagicMock) -> AsyncClient:
    """Yield an httpx AsyncClient with mocked Plaid service dependency."""
    factory = async_sessionmaker(bind=plaid_engine, class_=AsyncSession, expire_on_commit=False)

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

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user
    app.dependency_overrides[get_plaid_service] = lambda: mock_plaid_service

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


class TestLinkTokenEndpoint:
    """Tests for POST /api/v1/plaid/link-token."""

    @pytest.mark.anyio
    async def test_returns_link_token(
        self,
        plaid_client: AsyncClient,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should return a Plaid link token."""
        mock_plaid_service.create_link_token.return_value = "link-sandbox-test"

        response = await plaid_client.post("/api/v1/plaid/link-token", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["link_token"] == "link-sandbox-test"


class TestExchangeTokenEndpoint:
    """Tests for POST /api/v1/plaid/exchange-token."""

    @pytest.mark.anyio
    async def test_exchanges_token_and_creates_accounts(
        self,
        plaid_client: AsyncClient,
        plaid_session: AsyncSession,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should exchange public token and create account records."""
        mock_plaid_service.exchange_public_token.return_value = (
            "access-sandbox-xyz",
            "item-sandbox-abc",
        )
        mock_plaid_service.get_accounts.return_value = [
            {
                "account_id": "plaid-acct-1",
                "name": "My Checking",
                "type": "depository",
                "subtype": "checking",
                "balances": {"current": 1500.00, "available": 1400.00},
            }
        ]

        response = await plaid_client.post(
            "/api/v1/plaid/exchange-token",
            json={"public_token": "public-sandbox-123"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert "accounts" in data
        assert len(data["accounts"]) >= 1

    @pytest.mark.anyio
    async def test_exchange_missing_public_token_returns_422(
        self, plaid_client: AsyncClient, auth_headers: dict
    ) -> None:
        """Should return 422 if public_token is missing."""
        response = await plaid_client.post(
            "/api/v1/plaid/exchange-token",
            json={},
            headers=auth_headers,
        )
        assert response.status_code == 422


class TestSyncEndpoint:
    """Tests for POST /api/v1/plaid/sync/{account_id}."""

    @pytest.mark.anyio
    async def test_sync_triggers_transaction_sync(
        self,
        plaid_client: AsyncClient,
        plaid_session: AsyncSession,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should sync transactions for an account."""
        from datetime import UTC, datetime

        # Create an account with encrypted plaid credentials
        settings = get_settings()
        encrypted_token = encrypt_value(
            "access-sandbox-xyz", settings.plaid_encryption_key
        )
        account = Account(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            plaid_account_id="plaid-acct-1",
            plaid_access_token=encrypted_token,
            plaid_item_id="item-sandbox-abc",
            plaid_cursor=None,
            institution_name="Test Bank",
            account_name="Checking",
            account_type="checking",
            current_balance=Decimal("1000.00"),
            is_manual=False,
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        plaid_session.add(account)
        await plaid_session.flush()

        mock_plaid_service.sync_transactions.return_value = {
            "added": [{"transaction_id": "tx1", "amount": 42.0}],
            "modified": [],
            "removed": [],
            "next_cursor": "cursor-new",
            "has_more": False,
        }

        response = await plaid_client.post(
            f"/api/v1/plaid/sync/{account.id}",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["added_count"] >= 0

    @pytest.mark.anyio
    async def test_sync_nonexistent_account_returns_404(
        self,
        plaid_client: AsyncClient,
        auth_headers: dict,
    ) -> None:
        """Should return 404 for unknown account."""
        fake_id = uuid.uuid4()
        response = await plaid_client.post(
            f"/api/v1/plaid/sync/{fake_id}",
            headers=auth_headers,
        )
        assert response.status_code == 404


class TestHostedLinkTokenEndpoint:
    """Tests for POST /api/v1/plaid/hosted-link-token."""

    @pytest.mark.anyio
    async def test_returns_link_token_and_hosted_url(
        self,
        plaid_client: AsyncClient,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should return link_token and hosted_link_url on success."""
        mock_plaid_service.create_hosted_link_token.return_value = (
            "link-sandbox-hosted-abc",
            "https://hosted.plaid.com/sessions/test-session",
        )

        response = await plaid_client.post(
            "/api/v1/plaid/hosted-link-token",
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["link_token"] == "link-sandbox-hosted-abc"
        assert data["hosted_link_url"] == "https://hosted.plaid.com/sessions/test-session"

    @pytest.mark.anyio
    async def test_service_error_returns_502(
        self,
        plaid_client: AsyncClient,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should return 502 when PlaidService raises an error."""
        mock_plaid_service.create_hosted_link_token.side_effect = Exception(
            "Plaid API error"
        )

        response = await plaid_client.post(
            "/api/v1/plaid/hosted-link-token",
            headers=auth_headers,
        )
        assert response.status_code == 502
        assert "hosted link token" in response.json()["detail"].lower()


class TestResolveSessionEndpoint:
    """Tests for POST /api/v1/plaid/resolve-session."""

    @pytest.mark.anyio
    async def test_complete_session_returns_accounts(
        self,
        plaid_client: AsyncClient,
        plaid_session: AsyncSession,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should return status=complete with accounts when session is done."""
        mock_plaid_service.resolve_hosted_session.return_value = {
            "status": "complete",
            "public_token": "public-sandbox-hosted-xyz",
            "access_token": "access-sandbox-hosted-789",
            "item_id": "item-hosted-abc",
        }
        mock_plaid_service.get_accounts.return_value = [
            {
                "account_id": "plaid-acct-hosted-1",
                "name": "Hosted Checking",
                "official_name": "Test Bank Checking",
                "type": "depository",
                "subtype": "checking",
                "balances": {"current": 2500.00, "available": 2400.00},
            }
        ]

        # Pre-register link token in ownership cache
        _link_token_owners["link-sandbox-hosted-token"] = (TEST_USER_ID, time.time())

        response = await plaid_client.post(
            "/api/v1/plaid/resolve-session",
            json={"link_token": "link-sandbox-hosted-token"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "complete"
        assert data["accounts"] is not None
        assert len(data["accounts"]) >= 1

    @pytest.mark.anyio
    async def test_pending_session_returns_pending(
        self,
        plaid_client: AsyncClient,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should return status=pending when session is not yet complete."""
        mock_plaid_service.resolve_hosted_session.return_value = {
            "status": "pending",
        }

        # Pre-register link token in ownership cache
        _link_token_owners["link-sandbox-hosted-pending"] = (TEST_USER_ID, time.time())

        response = await plaid_client.post(
            "/api/v1/plaid/resolve-session",
            json={"link_token": "link-sandbox-hosted-pending"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "pending"
        assert data["accounts"] is None

    @pytest.mark.anyio
    async def test_missing_link_token_returns_422(
        self,
        plaid_client: AsyncClient,
        auth_headers: dict,
    ) -> None:
        """Should return 422 when link_token is missing from request body."""
        response = await plaid_client.post(
            "/api/v1/plaid/resolve-session",
            json={},
            headers=auth_headers,
        )
        assert response.status_code == 422

    @pytest.mark.anyio
    async def test_service_error_returns_502(
        self,
        plaid_client: AsyncClient,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """Should return 502 when PlaidService raises during resolve."""
        mock_plaid_service.resolve_hosted_session.side_effect = Exception(
            "Plaid API error"
        )

        # Pre-register link token in ownership cache
        _link_token_owners["link-sandbox-hosted-error"] = (TEST_USER_ID, time.time())

        response = await plaid_client.post(
            "/api/v1/plaid/resolve-session",
            json={"link_token": "link-sandbox-hosted-error"},
            headers=auth_headers,
        )
        assert response.status_code == 502


class TestRegressionExistingEndpoints:
    """Regression tests — existing endpoints still work after hosted link changes."""

    @pytest.mark.anyio
    async def test_link_token_endpoint_still_works(
        self,
        plaid_client: AsyncClient,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """POST /plaid/link-token should still function normally."""
        mock_plaid_service.create_link_token.return_value = "link-sandbox-regression"

        response = await plaid_client.post(
            "/api/v1/plaid/link-token",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["link_token"] == "link-sandbox-regression"

    @pytest.mark.anyio
    async def test_exchange_token_endpoint_still_works(
        self,
        plaid_client: AsyncClient,
        plaid_session: AsyncSession,
        mock_plaid_service: MagicMock,
        auth_headers: dict,
    ) -> None:
        """POST /plaid/exchange-token should still function normally."""
        mock_plaid_service.exchange_public_token.return_value = (
            "access-sandbox-regression",
            "item-sandbox-regression",
        )
        mock_plaid_service.get_accounts.return_value = [
            {
                "account_id": "plaid-acct-regression",
                "name": "Regression Checking",
                "type": "depository",
                "subtype": "checking",
                "balances": {"current": 500.00, "available": 450.00},
            }
        ]

        response = await plaid_client.post(
            "/api/v1/plaid/exchange-token",
            json={"public_token": "public-sandbox-regression"},
            headers=auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert "accounts" in data
        assert len(data["accounts"]) >= 1
