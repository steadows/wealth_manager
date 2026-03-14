"""Tests for sync router endpoints."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.models.account import Account
from app.models.debt import Debt
from app.models.enums import AccountType, DebtType, GoalType
from app.models.goal import FinancialGoal
from app.models.snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User
from app.services.auth_service import create_access_token

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")


def _auth_headers() -> dict[str, str]:
    """Return Authorization header with a valid test JWT."""
    token = create_access_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


async def _seed_user_and_data(client: AsyncClient) -> None:
    """Seed test data via the client's app DB override."""
    app = client._transport.app  # type: ignore[attr-defined]
    from app.dependencies import get_db

    override = app.dependency_overrides[get_db]

    async for session in override():
        user = User(
            id=TEST_USER_ID,
            apple_id="sync.test",
            email="sync@test.com",
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(user)
        await session.flush()

        old_time = datetime(2025, 1, 1, tzinfo=UTC)
        new_time = datetime(2025, 6, 1, tzinfo=UTC)

        old_account = Account(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            institution_name="Old Bank",
            account_name="Old Checking",
            account_type=AccountType.CHECKING,
            current_balance=Decimal("1000.0000"),
            is_manual=True,
            created_at=old_time,
            updated_at=old_time,
        )
        new_account = Account(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            institution_name="New Bank",
            account_name="New Savings",
            account_type=AccountType.SAVINGS,
            current_balance=Decimal("5000.0000"),
            is_manual=True,
            created_at=new_time,
            updated_at=new_time,
        )
        session.add_all([old_account, new_account])
        await session.flush()

        old_txn = Transaction(
            id=uuid.uuid4(),
            account_id=old_account.id,
            amount=Decimal("-50.0000"),
            date=old_time,
            category="food",
            created_at=old_time,
        )
        new_txn = Transaction(
            id=uuid.uuid4(),
            account_id=new_account.id,
            amount=Decimal("-100.0000"),
            date=new_time,
            category="shopping",
            created_at=new_time,
        )
        session.add_all([old_txn, new_txn])

        old_goal = FinancialGoal(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            goal_name="Old Goal",
            goal_type=GoalType.EMERGENCY_FUND,
            target_amount=Decimal("10000.0000"),
            current_amount=Decimal("2000.0000"),
            priority="high",
            created_at=old_time,
            updated_at=old_time,
        )
        new_goal = FinancialGoal(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            goal_name="New Goal",
            goal_type=GoalType.RETIREMENT,
            target_amount=Decimal("500000.0000"),
            current_amount=Decimal("50000.0000"),
            priority="medium",
            created_at=new_time,
            updated_at=new_time,
        )
        session.add_all([old_goal, new_goal])

        old_debt = Debt(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            debt_name="Old Loan",
            debt_type=DebtType.AUTO,
            original_balance=Decimal("20000.0000"),
            current_balance=Decimal("15000.0000"),
            interest_rate=Decimal("0.0500"),
            minimum_payment=Decimal("400.0000"),
            is_fixed_rate=True,
            created_at=old_time,
            updated_at=old_time,
        )
        new_debt = Debt(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            debt_name="New Card",
            debt_type=DebtType.CREDIT_CARD,
            original_balance=Decimal("5000.0000"),
            current_balance=Decimal("3000.0000"),
            interest_rate=Decimal("0.1900"),
            minimum_payment=Decimal("100.0000"),
            is_fixed_rate=False,
            created_at=new_time,
            updated_at=new_time,
        )
        session.add_all([old_debt, new_debt])

        old_snap = NetWorthSnapshot(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            date=old_time,
            total_assets=Decimal("50000.0000"),
            total_liabilities=Decimal("20000.0000"),
        )
        new_snap = NetWorthSnapshot(
            id=uuid.uuid4(),
            user_id=TEST_USER_ID,
            date=new_time,
            total_assets=Decimal("60000.0000"),
            total_liabilities=Decimal("18000.0000"),
        )
        session.add_all([old_snap, new_snap])
        await session.commit()


@pytest.mark.asyncio
async def test_get_sync_initial(client: AsyncClient) -> None:
    """GET /api/v1/sync without since param returns all data."""
    await _seed_user_and_data(client)

    resp = await client.get("/api/v1/sync/", headers=_auth_headers())
    assert resp.status_code == 200

    body = resp.json()
    assert body["success"] is True
    data = body["data"]
    assert len(data["accounts"]) == 2
    assert len(data["transactions"]) == 2
    assert len(data["goals"]) == 2
    assert len(data["debts"]) == 2
    assert len(data["snapshots"]) == 2
    assert "synced_at" in data


@pytest.mark.asyncio
async def test_get_sync_delta(client: AsyncClient) -> None:
    """GET /api/v1/sync/?since= returns only records after cutoff."""
    await _seed_user_and_data(client)

    cutoff = "2025-03-01T00:00:00+00:00"
    resp = await client.get("/api/v1/sync/", params={"since": cutoff}, headers=_auth_headers())
    assert resp.status_code == 200

    body = resp.json()
    data = body["data"]
    assert len(data["accounts"]) == 1
    assert data["accounts"][0]["account_name"] == "New Savings"
    assert len(data["transactions"]) == 1
    assert len(data["goals"]) == 1
    assert len(data["debts"]) == 1
    assert len(data["snapshots"]) == 1


@pytest.mark.asyncio
async def test_get_sync_empty_delta(client: AsyncClient) -> None:
    """GET /api/v1/sync with future since returns empty collections."""
    await _seed_user_and_data(client)

    future = "2027-01-01T00:00:00+00:00"
    resp = await client.get("/api/v1/sync/", params={"since": future}, headers=_auth_headers())
    assert resp.status_code == 200

    data = resp.json()["data"]
    assert len(data["accounts"]) == 0
    assert len(data["transactions"]) == 0
    assert len(data["goals"]) == 0
    assert len(data["debts"]) == 0
    assert len(data["snapshots"]) == 0


@pytest.mark.asyncio
async def test_post_sync_applies_changes(client: AsyncClient) -> None:
    """POST /api/v1/sync creates records from client changes."""
    await _seed_user_and_data(client)

    payload = {
        "accounts": [
            {
                "institution_name": "Mobile Bank",
                "account_name": "Mobile Checking",
                "account_type": "checking",
                "current_balance": "3000.00",
                "is_manual": True,
            }
        ],
        "goals": [
            {
                "goal_name": "Vacation Fund",
                "goal_type": "travel",
                "target_amount": "5000.00",
                "priority": "low",
            }
        ],
        "debts": [],
    }

    resp = await client.post("/api/v1/sync/", json=payload, headers=_auth_headers())
    assert resp.status_code == 200

    body = resp.json()
    assert body["success"] is True
    data = body["data"]
    assert data["applied_accounts"] == 1
    assert data["applied_goals"] == 1
    assert data["applied_debts"] == 0
    assert "synced_at" in data


@pytest.mark.asyncio
async def test_post_sync_empty_changes(client: AsyncClient) -> None:
    """POST /api/v1/sync with empty changes returns zero counts."""
    await _seed_user_and_data(client)

    resp = await client.post("/api/v1/sync/", json={}, headers=_auth_headers())
    assert resp.status_code == 200

    data = resp.json()["data"]
    assert data["applied_accounts"] == 0
    assert data["applied_goals"] == 0
    assert data["applied_debts"] == 0
