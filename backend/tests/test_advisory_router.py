"""Tests for advisory router endpoints (4.8)."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.routers.advisory import (
    build_snapshot,
    get_advisory_service,
    get_alert_service,
    get_report_service,
)
from app.schemas.advisory import (
    BriefingInsight,
    BriefingPeriod,
    CFOBriefing,
    DebtAnalysis,
    HealthScoreResponse,
    RetirementAnalysis,
    TaxAnalysis,
    UserFinancialSnapshot,
)
from app.services.auth_service import create_access_token
from tests.conftest import TEST_USER_ID

_SNAPSHOT = UserFinancialSnapshot(
    user_id=TEST_USER_ID,
    net_worth=Decimal("250000"),
    total_assets=Decimal("300000"),
    total_liabilities=Decimal("50000"),
)


def _auth_headers() -> dict[str, str]:
    """Return Authorization header with a valid test JWT."""
    token = create_access_token(TEST_USER_ID)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def mock_advisory_client(client: AsyncClient):
    """Client with advisory dependency overrides."""
    app = client._transport.app  # type: ignore[attr-defined]

    # Override build_snapshot to avoid DB queries
    async def override_build_snapshot(user_id, db):
        return _SNAPSHOT

    app.dependency_overrides[build_snapshot] = lambda: _SNAPSHOT

    yield client

    # Cleanup
    app.dependency_overrides.pop(build_snapshot, None)


@pytest.mark.asyncio
class TestAdvisoryRouter:
    """Tests for /api/v1/advisor and /api/v1/reports endpoints."""

    async def test_chat_endpoint_returns_streaming(self, client):
        """POST /advisor/chat should return a streaming response."""
        app = client._transport.app  # type: ignore[attr-defined]

        chunks = ["Hello", " there", "!"]

        async def mock_chat(**kwargs):
            for chunk in chunks:
                yield chunk

        mock_service = MagicMock()
        mock_service.chat = mock_chat

        app.dependency_overrides[get_advisory_service] = lambda: mock_service

        response = await client.post(
            "/api/v1/advisor/chat",
            json={"message": "What should I do?"},
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        assert "text/event-stream" in response.headers.get("content-type", "")

        app.dependency_overrides.pop(get_advisory_service, None)

    async def test_get_briefing_returns_report(self, client):
        """GET /reports/briefing should return a CFO briefing."""
        app = client._transport.app  # type: ignore[attr-defined]

        mock_service = AsyncMock()
        mock_service.generate_briefing = AsyncMock(
            return_value=CFOBriefing(
                period=BriefingPeriod.WEEKLY,
                generated_at=datetime.now(UTC),
                health_score=75,
                summary="Good week.",
                insights=[
                    BriefingInsight(title="Test", detail="Detail", impact="positive")
                ],
                action_items=["Do something"],
                goal_progress=[],
                net_worth_change=Decimal("1500"),
            )
        )

        app.dependency_overrides[get_report_service] = lambda: mock_service

        response = await client.get(
            "/api/v1/reports/briefing?period=weekly",
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["health_score"] == 75

        app.dependency_overrides.pop(get_report_service, None)

    async def test_get_alerts_returns_list(self, client):
        """GET /alerts should return a list of proactive alerts."""
        app = client._transport.app  # type: ignore[attr-defined]

        mock_service = MagicMock()
        mock_service.check_alerts = MagicMock(return_value=[])

        app.dependency_overrides[get_alert_service] = lambda: mock_service

        response = await client.get(
            "/api/v1/alerts",
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert isinstance(data["data"], list)

        app.dependency_overrides.pop(get_alert_service, None)

    async def test_analyze_retirement_endpoint(self, client):
        """POST /advisor/analyze/retirement should return analysis."""
        app = client._transport.app  # type: ignore[attr-defined]

        mock_service = AsyncMock()
        mock_service.analyze_retirement = AsyncMock(
            return_value=RetirementAnalysis(
                readiness_score=68,
                projected_shortfall=Decimal("150000"),
                fire_number=Decimal("1500000"),
                years_to_fire=22,
                recommendations=["Increase savings"],
                summary="On moderate path.",
            )
        )

        app.dependency_overrides[get_advisory_service] = lambda: mock_service

        response = await client.post(
            "/api/v1/advisor/analyze/retirement",
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["readiness_score"] == 68

        app.dependency_overrides.pop(get_advisory_service, None)

    async def test_analyze_tax_endpoint(self, client):
        """POST /advisor/analyze/tax should return analysis."""
        app = client._transport.app  # type: ignore[attr-defined]

        mock_service = AsyncMock()
        mock_service.analyze_tax = AsyncMock(
            return_value=TaxAnalysis(
                estimated_tax_burden=Decimal("24000"),
                effective_rate=Decimal("0.20"),
                optimization_opportunities=["Max HSA"],
                harvesting_candidates=[],
                summary="Two optimizations available.",
            )
        )

        app.dependency_overrides[get_advisory_service] = lambda: mock_service

        response = await client.post(
            "/api/v1/advisor/analyze/tax",
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

        app.dependency_overrides.pop(get_advisory_service, None)

    async def test_analyze_debt_endpoint(self, client):
        """POST /advisor/analyze/debt should return analysis."""
        app = client._transport.app  # type: ignore[attr-defined]

        mock_service = AsyncMock()
        mock_service.analyze_debt = AsyncMock(
            return_value=DebtAnalysis(
                total_debt=Decimal("30000"),
                weighted_avg_rate=Decimal("0.055"),
                recommended_strategy="avalanche",
                monthly_savings_potential=Decimal("200"),
                payoff_timeline_months=48,
                recommendations=["Pay extra"],
                summary="Focus on student loan.",
            )
        )

        app.dependency_overrides[get_advisory_service] = lambda: mock_service

        response = await client.post(
            "/api/v1/advisor/analyze/debt",
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

        app.dependency_overrides.pop(get_advisory_service, None)

    async def test_get_health_score_endpoint(self, client):
        """GET /reports/health-score should return score with narrative."""
        app = client._transport.app  # type: ignore[attr-defined]

        mock_service = AsyncMock()
        mock_service.generate_health_score = AsyncMock(
            return_value=HealthScoreResponse(
                overall_score=72,
                savings_score=80,
                debt_score=65,
                investment_score=70,
                emergency_fund_score=50,
                narrative="Good health overall.",
            )
        )

        app.dependency_overrides[get_report_service] = lambda: mock_service

        response = await client.get(
            "/api/v1/reports/health-score",
            headers=_auth_headers(),
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["overall_score"] == 72

        app.dependency_overrides.pop(get_report_service, None)

    async def test_chat_requires_message(self, client):
        """POST /advisor/chat should reject empty request body."""
        response = await client.post(
            "/api/v1/advisor/chat",
            json={},
            headers=_auth_headers(),
        )
        assert response.status_code == 422
