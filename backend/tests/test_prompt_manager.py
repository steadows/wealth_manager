"""Tests for prompt manager — template loading + context building (4.2)."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path

import pytest

from app.schemas.advisory import (
    AccountSummary,
    DebtSummary,
    GoalSummary,
    UserFinancialSnapshot,
)

# Prompts directory (relative to backend root)
PROMPTS_DIR = Path(__file__).parent.parent / "app" / "prompts"


def _make_snapshot(**overrides) -> UserFinancialSnapshot:
    """Create a test financial snapshot with sensible defaults."""
    defaults = {
        "user_id": uuid.UUID("00000000-0000-4000-a000-000000000001"),
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
                account_name="Checking",
                institution_name="Chase",
                account_type="checking",
                current_balance=Decimal("15000.00"),
            ),
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
        "goals": [
            GoalSummary(
                goal_name="Emergency Fund",
                goal_type="emergencyFund",
                target_amount=Decimal("30000.00"),
                current_amount=Decimal("15000.00"),
                target_date=datetime(2027, 6, 1, tzinfo=UTC),
            ),
        ],
        "health_score": 72,
    }
    defaults.update(overrides)
    return UserFinancialSnapshot(**defaults)


@pytest.mark.asyncio
class TestPromptManager:
    """Tests for PromptManager."""

    async def test_init_loads_templates_dir(self):
        """PromptManager should initialize with the templates directory."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        assert pm._prompts_dir == PROMPTS_DIR

    async def test_build_financial_context_includes_net_worth(self):
        """Financial context should include net worth figures."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        snapshot = _make_snapshot()
        context = pm.build_financial_context(snapshot)

        assert "250000.00" in context or "250,000" in context
        assert "300000.00" in context or "300,000" in context
        assert "50000.00" in context or "50,000" in context

    async def test_build_financial_context_includes_accounts(self):
        """Financial context should list accounts."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        snapshot = _make_snapshot()
        context = pm.build_financial_context(snapshot)

        assert "Checking" in context
        assert "Chase" in context
        assert "401k" in context
        assert "Fidelity" in context

    async def test_build_financial_context_includes_debts(self):
        """Financial context should list debts with rates."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        snapshot = _make_snapshot()
        context = pm.build_financial_context(snapshot)

        assert "Student Loan" in context
        assert "30000" in context or "30,000" in context
        assert "5.5" in context  # interest rate as percentage

    async def test_build_financial_context_includes_goals(self):
        """Financial context should list goals with progress."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        snapshot = _make_snapshot()
        context = pm.build_financial_context(snapshot)

        assert "Emergency Fund" in context
        assert "15000" in context or "15,000" in context

    async def test_build_financial_context_handles_empty_snapshot(self):
        """Financial context should handle snapshot with no accounts/debts/goals."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        snapshot = _make_snapshot(
            accounts=[], debts=[], goals=[], annual_income=None, monthly_expenses=None
        )
        context = pm.build_financial_context(snapshot)

        # Should still include net worth
        assert "250000" in context or "250,000" in context
        # Should not crash
        assert isinstance(context, str)
        assert len(context) > 0

    async def test_render_prompt_renders_jinja2_template(self):
        """render_prompt() should render a Jinja2 template with context."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        snapshot = _make_snapshot()

        result = pm.render_prompt(
            "weekly_briefing.jinja2",
            {
                "period": "weekly",
                "snapshot": snapshot,
                "calculations": {
                    "net_worth_change": Decimal("1500.00"),
                    "net_worth_change_pct": 0.6,
                    "top_spending_categories": [
                        {"name": "Housing", "amount": Decimal("2000.00")},
                        {"name": "Food", "amount": Decimal("800.00")},
                    ],
                    "alerts": [],
                },
            },
        )

        assert "Weekly" in result
        assert "250000.00" in result or "250,000" in result
        assert "Emergency Fund" in result

    async def test_render_prompt_raises_on_missing_template(self):
        """render_prompt() should raise when template doesn't exist."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)

        with pytest.raises(Exception):
            pm.render_prompt("nonexistent.jinja2", {})

    async def test_load_system_prompt_reads_file(self):
        """load_system_prompt() should read a system prompt file."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)
        prompt = pm.load_system_prompt("financial_advisor")

        assert "certified financial planner" in prompt.lower()
        assert "personal CFO" in prompt

    async def test_load_system_prompt_raises_on_missing(self):
        """load_system_prompt() should raise when file doesn't exist."""
        from app.services.prompt_manager import PromptManager

        pm = PromptManager(PROMPTS_DIR)

        with pytest.raises(FileNotFoundError):
            pm.load_system_prompt("nonexistent_persona")
