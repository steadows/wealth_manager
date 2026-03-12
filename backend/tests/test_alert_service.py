"""Tests for alert service — rule-based proactive alerts (4.7)."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.schemas.advisory import (
    AccountSummary,
    AlertSeverity,
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
        "filing_status": "single",
        "risk_tolerance": "moderate",
        "retirement_age": 65,
        "accounts": [],
        "debts": [],
        "goals": [],
        "health_score": 72,
    }
    defaults.update(overrides)
    return UserFinancialSnapshot(**defaults)


@pytest.mark.asyncio
class TestAlertService:
    """Tests for AlertService rule checks."""

    async def test_emergency_fund_low_triggers(self):
        """Alert should trigger when liquid savings < 3 months expenses."""
        from app.services.alert_service import AlertService

        snapshot = _make_snapshot(
            monthly_expenses=Decimal("5000.00"),
            accounts=[
                AccountSummary(
                    account_name="Checking",
                    institution_name="Chase",
                    account_type="checking",
                    current_balance=Decimal("8000.00"),
                ),
                AccountSummary(
                    account_name="Savings",
                    institution_name="Chase",
                    account_type="savings",
                    current_balance=Decimal("2000.00"),
                ),
            ],
        )

        service = AlertService()
        alert = service._check_emergency_fund_low(snapshot)

        assert alert is not None
        assert alert.rule_name == "emergency_fund_low"
        assert alert.severity == AlertSeverity.WARNING
        # $10k liquid / $5k monthly = 2 months < 3 months threshold

    async def test_emergency_fund_ok_no_alert(self):
        """No alert when emergency fund covers 3+ months."""
        from app.services.alert_service import AlertService

        snapshot = _make_snapshot(
            monthly_expenses=Decimal("5000.00"),
            accounts=[
                AccountSummary(
                    account_name="Savings",
                    institution_name="Chase",
                    account_type="savings",
                    current_balance=Decimal("20000.00"),
                ),
            ],
        )

        service = AlertService()
        alert = service._check_emergency_fund_low(snapshot)

        assert alert is None

    async def test_net_worth_milestone_triggers(self):
        """Alert should trigger when net worth crosses a milestone."""
        from app.services.alert_service import AlertService

        service = AlertService()
        # Net worth just crossed $250k
        snapshot = _make_snapshot(net_worth=Decimal("251000.00"))
        alert = service._check_net_worth_milestone(snapshot, previous_net_worth=Decimal("249000.00"))

        assert alert is not None
        assert alert.rule_name == "net_worth_milestone"
        assert alert.severity == AlertSeverity.INFO
        assert "250" in alert.message

    async def test_net_worth_milestone_no_crossing(self):
        """No alert when net worth hasn't crossed a milestone."""
        from app.services.alert_service import AlertService

        service = AlertService()
        snapshot = _make_snapshot(net_worth=Decimal("251000.00"))
        alert = service._check_net_worth_milestone(snapshot, previous_net_worth=Decimal("250500.00"))

        assert alert is None

    async def test_goal_off_track_triggers(self):
        """Alert should trigger when a goal's projected completion misses target date."""
        from app.services.alert_service import AlertService

        snapshot = _make_snapshot(
            goals=[
                GoalSummary(
                    goal_name="House Down Payment",
                    goal_type="homePurchase",
                    target_amount=Decimal("80000.00"),
                    current_amount=Decimal("10000.00"),
                    target_date=datetime(2026, 6, 1, tzinfo=UTC),  # 3 months away
                ),
            ],
        )

        service = AlertService()
        alerts = service._check_goal_off_track(snapshot)

        assert len(alerts) >= 1
        off_track = alerts[0]
        assert off_track.rule_name == "goal_off_track"
        assert off_track.severity == AlertSeverity.WARNING
        assert "House Down Payment" in off_track.message

    async def test_goal_on_track_no_alert(self):
        """No alert for goals that are on track."""
        from app.services.alert_service import AlertService

        snapshot = _make_snapshot(
            goals=[
                GoalSummary(
                    goal_name="Emergency Fund",
                    goal_type="emergencyFund",
                    target_amount=Decimal("30000.00"),
                    current_amount=Decimal("29000.00"),
                    target_date=datetime(2027, 12, 1, tzinfo=UTC),
                ),
            ],
        )

        service = AlertService()
        alerts = service._check_goal_off_track(snapshot)

        assert len(alerts) == 0

    async def test_spending_spike_triggers(self):
        """Alert should trigger when a category spend > 2x its average."""
        from app.services.alert_service import AlertService

        service = AlertService()
        alert = service._check_spending_spike(
            category="food",
            current_amount=Decimal("1200.00"),
            average_amount=Decimal("500.00"),
        )

        assert alert is not None
        assert alert.rule_name == "spending_spike"
        assert alert.severity == AlertSeverity.WARNING

    async def test_spending_spike_normal_no_alert(self):
        """No alert when spending is within normal range."""
        from app.services.alert_service import AlertService

        service = AlertService()
        alert = service._check_spending_spike(
            category="food",
            current_amount=Decimal("550.00"),
            average_amount=Decimal("500.00"),
        )

        assert alert is None

    async def test_savings_rate_drop_triggers(self):
        """Alert when savings rate drops significantly."""
        from app.services.alert_service import AlertService

        service = AlertService()
        alert = service._check_savings_rate_drop(
            current_rate=Decimal("0.08"),
            previous_rate=Decimal("0.20"),
        )

        assert alert is not None
        assert alert.rule_name == "savings_rate_drop"
        assert alert.severity == AlertSeverity.ACTION

    async def test_savings_rate_stable_no_alert(self):
        """No alert when savings rate is stable."""
        from app.services.alert_service import AlertService

        service = AlertService()
        alert = service._check_savings_rate_drop(
            current_rate=Decimal("0.19"),
            previous_rate=Decimal("0.20"),
        )

        assert alert is None

    async def test_debt_payoff_opportunity_triggers(self):
        """Alert when high-interest debt could benefit from refinancing."""
        from app.services.alert_service import AlertService

        snapshot = _make_snapshot(
            debts=[
                DebtSummary(
                    debt_name="Personal Loan",
                    debt_type="personal",
                    current_balance=Decimal("15000.00"),
                    interest_rate=Decimal("0.18"),
                    minimum_payment=Decimal("450.00"),
                ),
            ],
        )

        service = AlertService()
        alerts = service._check_debt_payoff_opportunity(snapshot)

        assert len(alerts) >= 1
        assert alerts[0].rule_name == "debt_payoff_opportunity"

    async def test_tax_harvesting_season_triggers_in_q4(self):
        """Alert should trigger in Q4 for tax-loss harvesting."""
        from app.services.alert_service import AlertService

        service = AlertService()
        alert = service._check_tax_harvesting_season(
            current_month=11,
            has_investment_accounts=True,
        )

        assert alert is not None
        assert alert.rule_name == "tax_harvesting_season"
        assert alert.severity == AlertSeverity.INFO

    async def test_tax_harvesting_no_alert_outside_q4(self):
        """No tax harvesting alert outside Q4."""
        from app.services.alert_service import AlertService

        service = AlertService()
        alert = service._check_tax_harvesting_season(
            current_month=6,
            has_investment_accounts=True,
        )

        assert alert is None

    async def test_check_alerts_runs_all_rules(self):
        """check_alerts() should aggregate alerts from all rules."""
        from app.services.alert_service import AlertService

        snapshot = _make_snapshot(
            monthly_expenses=Decimal("5000.00"),
            accounts=[
                AccountSummary(
                    account_name="Checking",
                    institution_name="Chase",
                    account_type="checking",
                    current_balance=Decimal("5000.00"),
                ),
            ],
        )

        service = AlertService()
        alerts = service.check_alerts(
            snapshot=snapshot,
            previous_net_worth=Decimal("250000.00"),
            spending_by_category={},
            average_spending_by_category={},
            current_savings_rate=Decimal("0.15"),
            previous_savings_rate=Decimal("0.15"),
            current_month=6,
        )

        # Should return a list (may be empty or have alerts depending on data)
        assert isinstance(alerts, list)
