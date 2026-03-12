"""Tests for report service — CFO briefing generation (4.6)."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.schemas.advisory import (
    AccountSummary,
    BriefingInsight,
    BriefingPeriod,
    BriefingSchema,
    DebtSummary,
    GoalSummary,
    UserFinancialSnapshot,
)

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")


def _make_snapshot(**overrides) -> UserFinancialSnapshot:
    """Create a test financial snapshot."""
    defaults = {
        "user_id": TEST_USER_ID,
        "net_worth": Decimal("250000.00"),
        "total_assets": Decimal("300000.00"),
        "total_liabilities": Decimal("50000.00"),
        "annual_income": Decimal("120000.00"),
        "monthly_expenses": Decimal("5000.00"),
        "accounts": [
            AccountSummary(
                account_name="Checking",
                institution_name="Chase",
                account_type="checking",
                current_balance=Decimal("15000.00"),
            ),
        ],
        "debts": [],
        "goals": [
            GoalSummary(
                goal_name="Emergency Fund",
                goal_type="emergencyFund",
                target_amount=Decimal("30000.00"),
                current_amount=Decimal("15000.00"),
            ),
        ],
        "health_score": 72,
    }
    defaults.update(overrides)
    return UserFinancialSnapshot(**defaults)


@pytest.mark.asyncio
class TestReportService:
    """Tests for ReportService."""

    async def test_generate_briefing_calls_claude(self):
        """generate_briefing() should render a prompt and call Claude for narrative."""
        from app.services.report_service import ReportService

        mock_claude = AsyncMock()
        mock_claude.structured_generate = AsyncMock(
            return_value=BriefingSchema(
                summary="Your net worth grew by $1,500 this week.",
                insights=[
                    BriefingInsight(
                        title="Savings Rate Up",
                        detail="Your savings rate increased to 22%.",
                        impact="positive",
                    ),
                ],
                action_items=["Increase 401k contribution by 1%"],
            )
        )

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.render_prompt = MagicMock(return_value="rendered prompt")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="system prompt")

        service = ReportService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        briefing = await service.generate_briefing(
            snapshot=snapshot,
            period=BriefingPeriod.WEEKLY,
            net_worth_change=Decimal("1500.00"),
        )

        assert briefing.period == BriefingPeriod.WEEKLY
        assert briefing.health_score == 72
        assert "net worth grew" in briefing.summary.lower() or briefing.summary != ""
        assert len(briefing.insights) >= 1
        assert len(briefing.action_items) >= 1
        mock_claude.structured_generate.assert_called_once()

    async def test_generate_briefing_includes_goal_progress(self):
        """Briefing should include goal progress from snapshot."""
        from app.services.report_service import ReportService

        mock_claude = AsyncMock()
        mock_claude.structured_generate = AsyncMock(
            return_value=BriefingSchema(
                summary="Summary.",
                insights=[],
                action_items=[],
            )
        )

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.render_prompt = MagicMock(return_value="rendered")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="system")

        service = ReportService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        briefing = await service.generate_briefing(
            snapshot=snapshot,
            period=BriefingPeriod.MONTHLY,
            net_worth_change=Decimal("5000.00"),
        )

        assert len(briefing.goal_progress) == 1
        assert briefing.goal_progress[0].goal_name == "Emergency Fund"

    async def test_generate_health_score_response(self):
        """generate_health_score() should return score with AI narrative."""
        from app.services.report_service import ReportService

        mock_claude = AsyncMock()
        mock_claude.generate = AsyncMock(
            return_value="Your financial health is good. Strong savings rate offsets moderate debt."
        )

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.build_financial_context = MagicMock(return_value="context")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="system")

        service = ReportService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        result = await service.generate_health_score(
            snapshot=snapshot,
            scores={
                "overall": 72,
                "savings": 80,
                "debt": 65,
                "investment": 70,
                "emergency_fund": 50,
            },
        )

        assert result.overall_score == 72
        assert result.savings_score == 80
        assert result.narrative != ""
        mock_claude.generate.assert_called_once()
