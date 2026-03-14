"""Rule-based proactive alert detection service."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from app.schemas.advisory import (
    AlertSeverity,
    ProactiveAlert,
    UserFinancialSnapshot,
)

# Thresholds
_EMERGENCY_FUND_MONTHS = 3
_SPENDING_SPIKE_MULTIPLIER = Decimal("2.0")
_SAVINGS_RATE_DROP_THRESHOLD = Decimal("0.05")  # 5 percentage points
_HIGH_INTEREST_THRESHOLD = Decimal("0.10")  # 10% APR
_MILESTONES = [
    Decimal("50000"),
    Decimal("100000"),
    Decimal("250000"),
    Decimal("500000"),
    Decimal("750000"),
    Decimal("1000000"),
    Decimal("2000000"),
    Decimal("5000000"),
]
_LIQUID_ACCOUNT_TYPES = {"checking", "savings"}


def _make_alert(
    severity: AlertSeverity,
    title: str,
    message: str,
    rule_name: str,
) -> ProactiveAlert:
    """Create a ProactiveAlert with generated id and timestamp."""
    return ProactiveAlert(
        id=uuid.uuid4(),
        severity=severity,
        title=title,
        message=message,
        rule_name=rule_name,
        created_at=datetime.now(UTC),
    )


class AlertService:
    """Runs rule-based checks against a user's financial data."""

    def check_alerts(
        self,
        *,
        snapshot: UserFinancialSnapshot,
        previous_net_worth: Decimal,
        spending_by_category: dict[str, Decimal],
        average_spending_by_category: dict[str, Decimal],
        current_savings_rate: Decimal,
        previous_savings_rate: Decimal,
        current_month: int,
    ) -> list[ProactiveAlert]:
        """Run all alert rules and return triggered alerts."""
        alerts: list[ProactiveAlert] = []

        # Emergency fund
        ef_alert = self._check_emergency_fund_low(snapshot)
        if ef_alert:
            alerts.append(ef_alert)

        # Net worth milestone
        nw_alert = self._check_net_worth_milestone(snapshot, previous_net_worth)
        if nw_alert:
            alerts.append(nw_alert)

        # Goal tracking
        goal_alerts = self._check_goal_off_track(snapshot)
        alerts.extend(goal_alerts)

        # Spending spikes
        for category, amount in spending_by_category.items():
            avg = average_spending_by_category.get(category, Decimal(0))
            spike_alert = self._check_spending_spike(category, amount, avg)
            if spike_alert:
                alerts.append(spike_alert)

        # Savings rate
        sr_alert = self._check_savings_rate_drop(current_savings_rate, previous_savings_rate)
        if sr_alert:
            alerts.append(sr_alert)

        # Debt payoff opportunities
        debt_alerts = self._check_debt_payoff_opportunity(snapshot)
        alerts.extend(debt_alerts)

        # Tax harvesting
        has_investments = any(a.account_type == "investment" for a in snapshot.accounts)
        th_alert = self._check_tax_harvesting_season(current_month, has_investments)
        if th_alert:
            alerts.append(th_alert)

        return alerts

    def _check_emergency_fund_low(self, snapshot: UserFinancialSnapshot) -> ProactiveAlert | None:
        """Alert if liquid savings < 3 months of expenses."""
        if snapshot.monthly_expenses is None or snapshot.monthly_expenses <= 0:
            return None

        liquid = sum(
            a.current_balance for a in snapshot.accounts if a.account_type in _LIQUID_ACCOUNT_TYPES
        )
        months_covered = liquid / snapshot.monthly_expenses

        if months_covered < _EMERGENCY_FUND_MONTHS:
            return _make_alert(
                severity=AlertSeverity.WARNING,
                title="Emergency Fund Low",
                message=(
                    f"Your liquid savings cover {months_covered:.1f} months of expenses. "
                    f"Aim for at least {_EMERGENCY_FUND_MONTHS} months "
                    f"(${snapshot.monthly_expenses * _EMERGENCY_FUND_MONTHS:,.2f})."
                ),
                rule_name="emergency_fund_low",
            )
        return None

    def _check_net_worth_milestone(
        self,
        snapshot: UserFinancialSnapshot,
        previous_net_worth: Decimal,
    ) -> ProactiveAlert | None:
        """Alert when net worth crosses a milestone threshold."""
        for milestone in _MILESTONES:
            if previous_net_worth < milestone <= snapshot.net_worth:
                return _make_alert(
                    severity=AlertSeverity.INFO,
                    title="Net Worth Milestone!",
                    message=(
                        f"Congratulations! Your net worth crossed "
                        f"${milestone:,.0f}. Current: ${snapshot.net_worth:,.2f}."
                    ),
                    rule_name="net_worth_milestone",
                )
        return None

    def _check_goal_off_track(self, snapshot: UserFinancialSnapshot) -> list[ProactiveAlert]:
        """Alert for goals projected to miss their target date."""
        alerts: list[ProactiveAlert] = []
        now = datetime.now(UTC)

        for goal in snapshot.goals:
            if goal.target_date is None:
                continue
            if goal.current_amount >= goal.target_amount:
                continue

            remaining = goal.target_amount - goal.current_amount
            months_left = max(
                (goal.target_date.year - now.year) * 12 + (goal.target_date.month - now.month),
                1,
            )

            # If progress rate suggests they won't make it
            if goal.current_amount > 0 and goal.target_amount > 0:
                progress_ratio = goal.current_amount / goal.target_amount
                if progress_ratio < Decimal("0.9") and remaining > 0:
                    required_monthly = remaining / months_left
                    if required_monthly > goal.current_amount * Decimal("0.1"):
                        alerts.append(
                            _make_alert(
                                severity=AlertSeverity.WARNING,
                                title=f"Goal Off Track: {goal.goal_name}",
                                message=(
                                    f"{goal.goal_name} needs ${required_monthly:,.2f}/mo "
                                    f"to reach ${goal.target_amount:,.2f} by "
                                    f"{goal.target_date.strftime('%Y-%m-%d')}. "
                                    f"Currently at {progress_ratio * 100:.0f}%."
                                ),
                                rule_name="goal_off_track",
                            )
                        )
        return alerts

    def _check_spending_spike(
        self,
        category: str,
        current_amount: Decimal,
        average_amount: Decimal,
    ) -> ProactiveAlert | None:
        """Alert when category spending exceeds 2x its average."""
        if average_amount <= 0:
            return None
        if current_amount > average_amount * _SPENDING_SPIKE_MULTIPLIER:
            ratio = current_amount / average_amount
            return _make_alert(
                severity=AlertSeverity.WARNING,
                title=f"Spending Spike: {category}",
                message=(
                    f"Your {category} spending (${current_amount:,.2f}) is "
                    f"{ratio:.1f}x your average (${average_amount:,.2f})."
                ),
                rule_name="spending_spike",
            )
        return None

    def _check_savings_rate_drop(
        self,
        current_rate: Decimal,
        previous_rate: Decimal,
    ) -> ProactiveAlert | None:
        """Alert when savings rate drops by more than 5 percentage points."""
        drop = previous_rate - current_rate
        if drop > _SAVINGS_RATE_DROP_THRESHOLD:
            return _make_alert(
                severity=AlertSeverity.ACTION,
                title="Savings Rate Declined",
                message=(
                    f"Your savings rate dropped from {previous_rate * 100:.1f}% "
                    f"to {current_rate * 100:.1f}%. "
                    f"Review recent spending changes."
                ),
                rule_name="savings_rate_drop",
            )
        return None

    def _check_debt_payoff_opportunity(
        self, snapshot: UserFinancialSnapshot
    ) -> list[ProactiveAlert]:
        """Alert when high-interest debts may benefit from refinancing."""
        alerts: list[ProactiveAlert] = []
        for debt in snapshot.debts:
            if debt.interest_rate >= _HIGH_INTEREST_THRESHOLD:
                alerts.append(
                    _make_alert(
                        severity=AlertSeverity.ACTION,
                        title=f"High Interest: {debt.debt_name}",
                        message=(
                            f"{debt.debt_name} has a {debt.interest_rate * 100:.1f}% rate "
                            f"on ${debt.current_balance:,.2f}. "
                            f"Consider refinancing or accelerating payoff."
                        ),
                        rule_name="debt_payoff_opportunity",
                    )
                )
        return alerts

    def _check_tax_harvesting_season(
        self,
        current_month: int,
        has_investment_accounts: bool,
    ) -> ProactiveAlert | None:
        """Alert in Q4 to consider tax-loss harvesting."""
        if current_month in (10, 11, 12) and has_investment_accounts:
            return _make_alert(
                severity=AlertSeverity.INFO,
                title="Tax-Loss Harvesting Season",
                message=(
                    "Q4 is the ideal time to review your portfolio for "
                    "tax-loss harvesting opportunities before year-end."
                ),
                rule_name="tax_harvesting_season",
            )
        return None
