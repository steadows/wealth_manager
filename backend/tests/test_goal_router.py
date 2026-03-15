"""Tests for POST /api/v1/goals endpoint — create a financial goal.

TDD Step 2 (RED): Tests written first, covering:
- Happy path: valid goal creation returns 201
- Input validation: missing required fields returns 422
- Input validation: negative target amount returns 422
- Input validation: invalid priority enum returns 422
- Input validation: empty goal name returns 422
- Input validation: past target date returns 422
- Persistence: created goal is retrievable
- Response shape: all expected fields present
- Decimal precision: money field round-trips correctly
- Edge case: optional fields default correctly
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient

from app.models.enums import GoalPriority, GoalType
from app.models.user import User
from app.services.auth_service import create_access_token

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")


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
            apple_id="goal-router.test",
            email="goalrouter@test.com",
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        session.add(user)
        await session.commit()


def _make_goal_payload(**overrides: object) -> dict:
    """Factory producing a valid goal creation payload with surgical overrides."""
    future_date = (datetime.now(UTC) + timedelta(days=365)).isoformat()
    defaults: dict = {
        "goal_name": "Emergency Fund",
        "goal_type": GoalType.EMERGENCY_FUND.value,
        "target_amount": "25000.00",
        "target_date": future_date,
        "priority": GoalPriority.HIGH.value,
    }
    defaults.update(overrides)
    return defaults


@pytest.mark.asyncio
class TestCreateGoal:
    """Tests for POST /api/v1/goals/."""

    async def test_create_valid_goal(self, client: AsyncClient) -> None:
        """Creates a goal with valid data and returns 201 with envelope."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        body = resp.json()
        assert body["success"] is True
        assert body["data"]["goal_name"] == "Emergency Fund"
        assert body["data"]["goal_type"] == GoalType.EMERGENCY_FUND.value
        assert body["data"]["target_amount"] == 25000.00
        assert body["data"]["priority"] == GoalPriority.HIGH.value

    async def test_create_returns_id(self, client: AsyncClient) -> None:
        """Created goal response includes a valid UUID id."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        goal_id = resp.json()["data"]["id"]
        # Verify it's a valid UUID string
        uuid.UUID(goal_id)

    async def test_create_returns_user_id(self, client: AsyncClient) -> None:
        """Created goal is associated with the authenticated user."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        assert resp.json()["data"]["user_id"] == str(TEST_USER_ID)

    async def test_create_missing_goal_name(self, client: AsyncClient) -> None:
        """Returns 422 when goal_name is missing."""
        await _seed_user(client)
        payload = _make_goal_payload()
        del payload["goal_name"]

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_empty_goal_name(self, client: AsyncClient) -> None:
        """Returns 422 when goal_name is an empty string."""
        await _seed_user(client)
        payload = _make_goal_payload(goal_name="")

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_missing_target_amount(self, client: AsyncClient) -> None:
        """Returns 422 when target_amount is missing."""
        await _seed_user(client)
        payload = _make_goal_payload()
        del payload["target_amount"]

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_negative_target_amount(self, client: AsyncClient) -> None:
        """Returns 422 when target_amount is negative."""
        await _seed_user(client)
        payload = _make_goal_payload(target_amount="-100.00")

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_zero_target_amount(self, client: AsyncClient) -> None:
        """Returns 422 when target_amount is zero (must be positive)."""
        await _seed_user(client)
        payload = _make_goal_payload(target_amount="0.00")

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_invalid_priority(self, client: AsyncClient) -> None:
        """Returns 422 when priority is not a valid enum value."""
        await _seed_user(client)
        payload = _make_goal_payload(priority="invalid_priority")

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_invalid_goal_type(self, client: AsyncClient) -> None:
        """Returns 422 when goal_type is not a valid enum value."""
        await _seed_user(client)
        payload = _make_goal_payload(goal_type="notAGoalType")

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_missing_priority(self, client: AsyncClient) -> None:
        """Returns 422 when priority is missing."""
        await _seed_user(client)
        payload = _make_goal_payload()
        del payload["priority"]

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_past_target_date(self, client: AsyncClient) -> None:
        """Returns 422 when target_date is in the past."""
        await _seed_user(client)
        past_date = (datetime.now(UTC) - timedelta(days=30)).isoformat()
        payload = _make_goal_payload(target_date=past_date)

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 422

    async def test_create_optional_target_date_defaults_none(self, client: AsyncClient) -> None:
        """target_date is optional and defaults to None."""
        await _seed_user(client)
        payload = _make_goal_payload()
        del payload["target_date"]

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        assert resp.json()["data"]["target_date"] is None

    async def test_create_defaults_current_amount_zero(self, client: AsyncClient) -> None:
        """current_amount defaults to 0 when not provided."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        assert resp.json()["data"]["current_amount"] == 0.0

    async def test_create_defaults_is_active_true(self, client: AsyncClient) -> None:
        """is_active defaults to True when not provided."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        assert resp.json()["data"]["is_active"] is True

    async def test_create_response_has_timestamps(self, client: AsyncClient) -> None:
        """Created goal response includes created_at and updated_at."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        data = resp.json()["data"]
        assert "created_at" in data
        assert "updated_at" in data

    async def test_create_response_all_fields(self, client: AsyncClient) -> None:
        """Response envelope contains all expected GoalResponse fields."""
        await _seed_user(client)
        payload = _make_goal_payload()

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        data = resp.json()["data"]
        expected_fields = {
            "id",
            "user_id",
            "goal_name",
            "goal_type",
            "target_amount",
            "current_amount",
            "target_date",
            "monthly_contribution",
            "priority",
            "is_active",
            "notes",
            "created_at",
            "updated_at",
        }
        assert expected_fields.issubset(set(data.keys()))

    async def test_create_decimal_precision(self, client: AsyncClient) -> None:
        """Decimal target_amount preserves precision through round-trip."""
        await _seed_user(client)
        payload = _make_goal_payload(target_amount="123456.7891")

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        assert resp.json()["data"]["target_amount"] == 123456.7891

    async def test_create_with_all_optional_fields(self, client: AsyncClient) -> None:
        """Goal creation succeeds with all optional fields specified."""
        await _seed_user(client)
        payload = _make_goal_payload(
            current_amount="5000.00",
            monthly_contribution="500.00",
            notes="Save for rainy day",
            is_active=False,
        )

        resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["current_amount"] == 5000.00
        assert data["monthly_contribution"] == 500.00
        assert data["notes"] == "Save for rainy day"
        assert data["is_active"] is False

    async def test_create_all_priority_values(self, client: AsyncClient) -> None:
        """All valid GoalPriority enum values are accepted."""
        await _seed_user(client)
        for priority in GoalPriority:
            payload = _make_goal_payload(
                goal_name=f"Goal {priority.value}",
                priority=priority.value,
            )

            resp = await client.post("/api/v1/goals/", json=payload, headers=_auth_headers())

            assert resp.status_code == 201, f"Failed for priority={priority.value}"
            assert resp.json()["data"]["priority"] == priority.value
