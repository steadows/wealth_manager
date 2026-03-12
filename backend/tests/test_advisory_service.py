"""Tests for advisory service — orchestrator (4.5)."""

import uuid
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.schemas.advisory import (
    AccountSummary,
    DebtAnalysis,
    DebtSummary,
    GoalSummary,
    RetirementAnalysis,
    TaxAnalysis,
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
        "filing_status": "single",
        "risk_tolerance": "moderate",
        "retirement_age": 65,
        "accounts": [
            AccountSummary(
                account_name="401k",
                institution_name="Fidelity",
                account_type="retirement",
                current_balance=Decimal("200000.00"),
            ),
        ],
        "debts": [
            DebtSummary(
                debt_name="Student Loan",
                debt_type="student",
                current_balance=Decimal("30000.00"),
                interest_rate=Decimal("0.055"),
                minimum_payment=Decimal("350.00"),
            ),
        ],
        "goals": [],
        "health_score": 72,
    }
    defaults.update(overrides)
    return UserFinancialSnapshot(**defaults)


@pytest.mark.asyncio
class TestAdvisoryService:
    """Tests for AdvisoryService."""

    async def test_chat_streams_response_with_context(self):
        """chat() should stream Claude response with financial context injected."""
        from app.services.advisory_service import AdvisoryService

        chunks = ["You should", " increase your", " 401k contribution."]

        async def mock_stream(*args, **kwargs):
            for chunk in chunks:
                yield chunk

        mock_claude = AsyncMock()
        mock_claude.stream = mock_stream

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.build_financial_context = MagicMock(return_value="context data")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="advisor prompt")

        service = AdvisoryService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        collected = []
        async for text in service.chat(snapshot=snapshot, user_message="What should I do?"):
            collected.append(text)

        assert collected == chunks
        # Verify context was built
        mock_prompt_manager.build_financial_context.assert_called_once_with(snapshot)

    async def test_analyze_retirement_returns_structured(self):
        """analyze_retirement() should return RetirementAnalysis."""
        from app.services.advisory_service import AdvisoryService

        expected = RetirementAnalysis(
            readiness_score=68,
            projected_shortfall=Decimal("150000.00"),
            fire_number=Decimal("1500000.00"),
            years_to_fire=22,
            recommendations=["Increase 401k contribution", "Open Roth IRA"],
            summary="You are on a moderate path to retirement.",
        )

        mock_claude = AsyncMock()
        mock_claude.structured_generate = AsyncMock(return_value=expected)

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.build_financial_context = MagicMock(return_value="context")
        mock_prompt_manager.render_prompt = MagicMock(return_value="rendered prompt")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="system prompt")

        service = AdvisoryService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        result = await service.analyze_retirement(snapshot=snapshot)

        assert isinstance(result, RetirementAnalysis)
        assert result.readiness_score == 68
        assert result.fire_number == Decimal("1500000.00")
        mock_claude.structured_generate.assert_called_once()

    async def test_analyze_tax_returns_structured(self):
        """analyze_tax() should return TaxAnalysis."""
        from app.services.advisory_service import AdvisoryService

        expected = TaxAnalysis(
            estimated_tax_burden=Decimal("24000.00"),
            effective_rate=Decimal("0.20"),
            optimization_opportunities=["Max out HSA", "Contribute to traditional IRA"],
            harvesting_candidates=["VTI lot from 2024"],
            summary="You have two key optimization opportunities.",
        )

        mock_claude = AsyncMock()
        mock_claude.structured_generate = AsyncMock(return_value=expected)

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.build_financial_context = MagicMock(return_value="context")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="system")

        service = AdvisoryService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        result = await service.analyze_tax(snapshot=snapshot)

        assert isinstance(result, TaxAnalysis)
        assert result.effective_rate == Decimal("0.20")

    async def test_analyze_debt_returns_structured(self):
        """analyze_debt() should return DebtAnalysis."""
        from app.services.advisory_service import AdvisoryService

        expected = DebtAnalysis(
            total_debt=Decimal("30000.00"),
            weighted_avg_rate=Decimal("0.055"),
            recommended_strategy="avalanche",
            monthly_savings_potential=Decimal("200.00"),
            payoff_timeline_months=48,
            recommendations=["Make extra payments to student loan"],
            summary="Focus on your student loan — it's your only debt.",
        )

        mock_claude = AsyncMock()
        mock_claude.structured_generate = AsyncMock(return_value=expected)

        mock_prompt_manager = MagicMock()
        mock_prompt_manager.build_financial_context = MagicMock(return_value="context")
        mock_prompt_manager.load_system_prompt = MagicMock(return_value="system")

        service = AdvisoryService(
            claude_service=mock_claude,
            prompt_manager=mock_prompt_manager,
        )

        snapshot = _make_snapshot()
        result = await service.analyze_debt(snapshot=snapshot)

        assert isinstance(result, DebtAnalysis)
        assert result.recommended_strategy == "avalanche"
        assert result.payoff_timeline_months == 48
