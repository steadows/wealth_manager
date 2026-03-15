"""Tests for account CRUD router — list, get, create, update, delete."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.models.account import Account
from app.models.enums import AccountType
from app.models.user import User
from app.services.auth_service import create_access_token

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")
OTHER_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000099")


def _auth_headers() -> dict[str, str]:
    """Return Authorization header with a valid test JWT."""
    token = create_access_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


async def _seed_user(client: AsyncClient) -> None:
    """Seed a test user via the client's DB override."""
    app = client._transport.app  # type: ignore[attr-defined]
    from app.dependencies import get_db

    override = app.dependency_overrides[get_db]
    async for session in override():
        user = User(
            id=TEST_USER_ID,
            apple_id="acct-router.test",
            email="acctrouter@test.com",
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(user)
        await session.commit()


async def _seed_user_and_accounts(client: AsyncClient) -> list[uuid.UUID]:
    """Seed a test user with three accounts. Returns account IDs."""
    app = client._transport.app  # type: ignore[attr-defined]
    from app.dependencies import get_db

    override = app.dependency_overrides[get_db]
    ids: list[uuid.UUID] = []
    async for session in override():
        user = User(
            id=TEST_USER_ID,
            apple_id="acct-router.test",
            email="acctrouter@test.com",
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(user)
        await session.flush()

        for _i, (name, atype, balance) in enumerate(
            [
                ("Checking", AccountType.CHECKING, Decimal("5000.0000")),
                ("Savings", AccountType.SAVINGS, Decimal("10000.0000")),
                ("Credit Card", AccountType.CREDIT_CARD, Decimal("2500.0000")),
            ]
        ):
            acct_id = uuid.uuid4()
            ids.append(acct_id)
            account = Account(
                id=acct_id,
                user_id=TEST_USER_ID,
                institution_name="Test Bank",
                account_name=name,
                account_type=atype,
                current_balance=balance,
                is_manual=True,
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
            session.add(account)
        await session.commit()
    return ids


async def _seed_other_user_account(client: AsyncClient) -> uuid.UUID:
    """Seed an account owned by a different user. Returns the account ID."""
    app = client._transport.app  # type: ignore[attr-defined]
    from app.dependencies import get_db

    override = app.dependency_overrides[get_db]
    acct_id = uuid.uuid4()
    async for session in override():
        other_user = User(
            id=OTHER_USER_ID,
            apple_id="other-user.test",
            email="other@test.com",
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(other_user)
        await session.flush()

        account = Account(
            id=acct_id,
            user_id=OTHER_USER_ID,
            institution_name="Other Bank",
            account_name="Other Checking",
            account_type=AccountType.CHECKING,
            current_balance=Decimal("9999.0000"),
            is_manual=True,
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(account)
        await session.commit()
    return acct_id


class TestListAccounts:
    """Tests for GET /api/v1/accounts/."""

    @pytest.mark.asyncio
    async def test_list_empty(self, client: AsyncClient) -> None:
        """Returns empty list when user has no accounts."""
        await _seed_user(client)
        resp = await client.get("/api/v1/accounts/", headers=_auth_headers())
        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert body["data"] == []

    @pytest.mark.asyncio
    async def test_list_with_data(self, client: AsyncClient) -> None:
        """Returns all accounts for the authenticated user."""
        await _seed_user_and_accounts(client)
        resp = await client.get("/api/v1/accounts/", headers=_auth_headers())
        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert len(body["data"]) == 3
        names = {a["account_name"] for a in body["data"]}
        assert names == {"Checking", "Savings", "Credit Card"}

    @pytest.mark.asyncio
    async def test_list_pagination_offset(self, client: AsyncClient) -> None:
        """Pagination offset skips the first N accounts."""
        await _seed_user_and_accounts(client)
        resp = await client.get(
            "/api/v1/accounts/",
            params={"offset": 2, "limit": 10},
            headers=_auth_headers(),
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]) == 1

    @pytest.mark.asyncio
    async def test_list_pagination_limit(self, client: AsyncClient) -> None:
        """Pagination limit restricts the number of returned accounts."""
        await _seed_user_and_accounts(client)
        resp = await client.get(
            "/api/v1/accounts/",
            params={"limit": 2},
            headers=_auth_headers(),
        )
        assert resp.status_code == 200
        assert len(resp.json()["data"]) == 2

    @pytest.mark.asyncio
    async def test_list_excludes_other_users(self, client: AsyncClient) -> None:
        """Only returns accounts belonging to the authenticated user."""
        await _seed_user_and_accounts(client)
        await _seed_other_user_account(client)
        resp = await client.get("/api/v1/accounts/", headers=_auth_headers())
        assert resp.status_code == 200
        assert len(resp.json()["data"]) == 3


class TestGetAccount:
    """Tests for GET /api/v1/accounts/{account_id}."""

    @pytest.mark.asyncio
    async def test_get_existing(self, client: AsyncClient) -> None:
        """Returns account data when it exists and belongs to the user."""
        ids = await _seed_user_and_accounts(client)
        resp = await client.get(f"/api/v1/accounts/{ids[0]}", headers=_auth_headers())
        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert body["data"]["id"] == str(ids[0])
        assert body["data"]["account_name"] == "Checking"

    @pytest.mark.asyncio
    async def test_get_not_found(self, client: AsyncClient) -> None:
        """Returns 404 for a nonexistent account ID."""
        await _seed_user(client)
        fake_id = uuid.uuid4()
        resp = await client.get(f"/api/v1/accounts/{fake_id}", headers=_auth_headers())
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_get_wrong_user(self, client: AsyncClient) -> None:
        """Returns 404 when requesting another user's account."""
        await _seed_user(client)
        other_acct_id = await _seed_other_user_account(client)
        resp = await client.get(f"/api/v1/accounts/{other_acct_id}", headers=_auth_headers())
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_get_response_fields(self, client: AsyncClient) -> None:
        """Response contains all expected fields."""
        ids = await _seed_user_and_accounts(client)
        resp = await client.get(f"/api/v1/accounts/{ids[0]}", headers=_auth_headers())
        data = resp.json()["data"]
        expected_fields = {
            "id",
            "institution_name",
            "account_name",
            "account_type",
            "current_balance",
            "available_balance",
            "currency",
            "is_manual",
            "is_hidden",
            "last_synced_at",
            "created_at",
            "updated_at",
            "plaid_account_id",
        }
        assert expected_fields.issubset(set(data.keys()))


class TestCreateAccount:
    """Tests for POST /api/v1/accounts/."""

    @pytest.mark.asyncio
    async def test_create_valid(self, client: AsyncClient) -> None:
        """Creates an account with valid data and returns 201."""
        await _seed_user(client)
        payload = {
            "institution_name": "New Bank",
            "account_name": "New Checking",
            "account_type": "checking",
            "current_balance": "3500.00",
            "is_manual": True,
        }
        resp = await client.post("/api/v1/accounts/", json=payload, headers=_auth_headers())
        assert resp.status_code == 201
        body = resp.json()
        assert body["success"] is True
        assert body["data"]["account_name"] == "New Checking"
        assert body["data"]["institution_name"] == "New Bank"
        assert body["data"]["currency"] == "USD"  # default

    @pytest.mark.asyncio
    async def test_create_with_optional_fields(self, client: AsyncClient) -> None:
        """Creates an account with optional fields like available_balance."""
        await _seed_user(client)
        payload = {
            "institution_name": "Full Bank",
            "account_name": "Full Account",
            "account_type": "savings",
            "current_balance": "10000.00",
            "available_balance": "9500.00",
            "currency": "EUR",
            "is_manual": False,
        }
        resp = await client.post("/api/v1/accounts/", json=payload, headers=_auth_headers())
        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["available_balance"] == 9500.00
        assert data["currency"] == "EUR"
        assert data["is_manual"] is False

    @pytest.mark.asyncio
    async def test_create_missing_required_fields(self, client: AsyncClient) -> None:
        """Returns 422 when required fields are missing."""
        await _seed_user(client)
        resp = await client.post(
            "/api/v1/accounts/",
            json={"account_name": "Incomplete"},
            headers=_auth_headers(),
        )
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_invalid_account_type(self, client: AsyncClient) -> None:
        """Returns 422 when account_type is not a valid enum value."""
        await _seed_user(client)
        payload = {
            "institution_name": "Bank",
            "account_name": "Bad Type",
            "account_type": "invalid_type",
            "current_balance": "1000.00",
            "is_manual": True,
        }
        resp = await client.post("/api/v1/accounts/", json=payload, headers=_auth_headers())
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_create_persists_to_db(self, client: AsyncClient) -> None:
        """Created account is retrievable via GET."""
        await _seed_user(client)
        payload = {
            "institution_name": "Persist Bank",
            "account_name": "Persist Checking",
            "account_type": "checking",
            "current_balance": "777.00",
            "is_manual": True,
        }
        create_resp = await client.post("/api/v1/accounts/", json=payload, headers=_auth_headers())
        acct_id = create_resp.json()["data"]["id"]
        get_resp = await client.get(f"/api/v1/accounts/{acct_id}", headers=_auth_headers())
        assert get_resp.status_code == 200
        assert get_resp.json()["data"]["account_name"] == "Persist Checking"

    @pytest.mark.asyncio
    async def test_create_negative_balance(self, client: AsyncClient) -> None:
        """Accounts can have negative balances (e.g., overdraft)."""
        await _seed_user(client)
        payload = {
            "institution_name": "Overdraft Bank",
            "account_name": "Overdraft",
            "account_type": "checking",
            "current_balance": "-250.00",
            "is_manual": True,
        }
        resp = await client.post("/api/v1/accounts/", json=payload, headers=_auth_headers())
        assert resp.status_code == 201
        assert resp.json()["data"]["current_balance"] == -250.00


class TestUpdateAccount:
    """Tests for PATCH /api/v1/accounts/{account_id}."""

    @pytest.mark.asyncio
    async def test_partial_update(self, client: AsyncClient) -> None:
        """Partial update changes only the provided fields."""
        ids = await _seed_user_and_accounts(client)
        resp = await client.patch(
            f"/api/v1/accounts/{ids[0]}",
            json={"account_name": "Updated Checking"},
            headers=_auth_headers(),
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["account_name"] == "Updated Checking"
        assert data["institution_name"] == "Test Bank"  # unchanged

    @pytest.mark.asyncio
    async def test_update_balance(self, client: AsyncClient) -> None:
        """Can update the current_balance field."""
        ids = await _seed_user_and_accounts(client)
        resp = await client.patch(
            f"/api/v1/accounts/{ids[0]}",
            json={"current_balance": "7777.77"},
            headers=_auth_headers(),
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["current_balance"] == 7777.77

    @pytest.mark.asyncio
    async def test_update_not_found(self, client: AsyncClient) -> None:
        """Returns 404 for a nonexistent account."""
        await _seed_user(client)
        fake_id = uuid.uuid4()
        resp = await client.patch(
            f"/api/v1/accounts/{fake_id}",
            json={"account_name": "Nope"},
            headers=_auth_headers(),
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_update_wrong_user(self, client: AsyncClient) -> None:
        """Returns 404 when trying to update another user's account."""
        await _seed_user(client)
        other_id = await _seed_other_user_account(client)
        resp = await client.patch(
            f"/api/v1/accounts/{other_id}",
            json={"account_name": "Hijacked"},
            headers=_auth_headers(),
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_update_hidden_flag(self, client: AsyncClient) -> None:
        """Can toggle the is_hidden flag via PATCH."""
        ids = await _seed_user_and_accounts(client)
        resp = await client.patch(
            f"/api/v1/accounts/{ids[0]}",
            json={"is_hidden": True},
            headers=_auth_headers(),
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["is_hidden"] is True


class TestDeleteAccount:
    """Tests for DELETE /api/v1/accounts/{account_id}."""

    @pytest.mark.asyncio
    async def test_delete_existing(self, client: AsyncClient) -> None:
        """Deleting an existing account returns 204."""
        ids = await _seed_user_and_accounts(client)
        resp = await client.delete(f"/api/v1/accounts/{ids[0]}", headers=_auth_headers())
        assert resp.status_code == 204

    @pytest.mark.asyncio
    async def test_delete_removes_from_db(self, client: AsyncClient) -> None:
        """Deleted account is no longer retrievable."""
        ids = await _seed_user_and_accounts(client)
        await client.delete(f"/api/v1/accounts/{ids[0]}", headers=_auth_headers())
        get_resp = await client.get(f"/api/v1/accounts/{ids[0]}", headers=_auth_headers())
        assert get_resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_not_found(self, client: AsyncClient) -> None:
        """Deleting a nonexistent account returns 404."""
        await _seed_user(client)
        fake_id = uuid.uuid4()
        resp = await client.delete(f"/api/v1/accounts/{fake_id}", headers=_auth_headers())
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_wrong_user(self, client: AsyncClient) -> None:
        """Cannot delete another user's account (404)."""
        await _seed_user(client)
        other_id = await _seed_other_user_account(client)
        resp = await client.delete(f"/api/v1/accounts/{other_id}", headers=_auth_headers())
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_reduces_count(self, client: AsyncClient) -> None:
        """After deletion, account list count decreases by one."""
        ids = await _seed_user_and_accounts(client)
        await client.delete(f"/api/v1/accounts/{ids[0]}", headers=_auth_headers())
        resp = await client.get("/api/v1/accounts/", headers=_auth_headers())
        assert len(resp.json()["data"]) == 2
