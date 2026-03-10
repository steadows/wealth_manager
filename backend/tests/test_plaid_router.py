"""Tests for plaid router — link-token, exchange-token, sync endpoints."""

from __future__ import annotations

import os
import uuid
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.dependencies import get_current_user, get_db
from app.main import create_app
from app.models.account import Account
from app.services.auth_service import create_access_token
from app.services.plaid_service import get_plaid_service

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
    factory = async_sessionmaker(
        bind=plaid_engine, class_=AsyncSession, expire_on_commit=False
    )
    async with factory() as sess:
        yield sess


@pytest.fixture
def mock_plaid_service() -> MagicMock:
    """Create a mock PlaidService."""
    return MagicMock()


@pytest.fixture
async def plaid_client(
    plaid_engine, mock_plaid_service: MagicMock
) -> AsyncClient:
    """Yield an httpx AsyncClient with mocked Plaid service dependency."""
    factory = async_sessionmaker(
        bind=plaid_engine, class_=AsyncSession, expire_on_commit=False
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

        response = await plaid_client.post(
            "/api/v1/plaid/link-token", headers=auth_headers
        )
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

        # Create an account with plaid credentials
        account = Account(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            plaid_account_id="plaid-acct-1",
            plaid_access_token="access-sandbox-xyz",
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
