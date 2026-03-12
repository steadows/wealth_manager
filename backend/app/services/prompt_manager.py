"""Prompt template loading and financial context building."""

from decimal import Decimal
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from app.schemas.advisory import UserFinancialSnapshot


class PromptManager:
    """Loads system prompts and renders Jinja2 templates with financial context."""

    def __init__(self, prompts_dir: Path) -> None:
        self._prompts_dir = prompts_dir
        self._env = Environment(
            loader=FileSystemLoader(str(prompts_dir / "templates")),
            autoescape=False,
        )

    def load_system_prompt(self, name: str) -> str:
        """Load a system prompt text file by name (without extension).

        Raises:
            FileNotFoundError: If the prompt file does not exist.
        """
        path = self._prompts_dir / "system" / f"{name}.txt"
        if not path.exists():
            raise FileNotFoundError(f"System prompt not found: {path}")
        return path.read_text(encoding="utf-8").strip()

    def build_financial_context(self, snapshot: UserFinancialSnapshot) -> str:
        """Build a structured text block from a user's financial snapshot."""
        lines: list[str] = []

        lines.append("=== FINANCIAL OVERVIEW ===")
        lines.append(f"Net Worth: ${snapshot.net_worth:,.2f}")
        lines.append(f"Total Assets: ${snapshot.total_assets:,.2f}")
        lines.append(f"Total Liabilities: ${snapshot.total_liabilities:,.2f}")

        if snapshot.annual_income is not None:
            lines.append(f"Annual Income: ${snapshot.annual_income:,.2f}")
        if snapshot.monthly_expenses is not None:
            lines.append(f"Monthly Expenses: ${snapshot.monthly_expenses:,.2f}")

        lines.append(f"Filing Status: {snapshot.filing_status}")
        lines.append(f"Risk Tolerance: {snapshot.risk_tolerance}")
        lines.append(f"Retirement Age: {snapshot.retirement_age}")

        if snapshot.health_score is not None:
            lines.append(f"Financial Health Score: {snapshot.health_score}/100")

        if snapshot.accounts:
            lines.append("")
            lines.append("=== ACCOUNTS ===")
            for acct in snapshot.accounts:
                lines.append(
                    f"- {acct.account_name} ({acct.institution_name}, "
                    f"{acct.account_type}): ${acct.current_balance:,.2f}"
                )

        if snapshot.debts:
            lines.append("")
            lines.append("=== DEBTS ===")
            for debt in snapshot.debts:
                rate_pct = debt.interest_rate * 100
                lines.append(
                    f"- {debt.debt_name} ({debt.debt_type}): "
                    f"${debt.current_balance:,.2f} at {rate_pct:.1f}% APR, "
                    f"min payment ${debt.minimum_payment:,.2f}/mo"
                )

        if snapshot.goals:
            lines.append("")
            lines.append("=== GOALS ===")
            for goal in snapshot.goals:
                progress = (
                    (goal.current_amount / goal.target_amount * 100)
                    if goal.target_amount > 0
                    else Decimal(0)
                )
                line = (
                    f"- {goal.goal_name} ({goal.goal_type}): "
                    f"${goal.current_amount:,.2f} / ${goal.target_amount:,.2f} "
                    f"({progress:.1f}%)"
                )
                if goal.target_date:
                    line += f" — due {goal.target_date.strftime('%Y-%m-%d')}"
                lines.append(line)

        return "\n".join(lines)

    def render_prompt(self, template_name: str, context: dict) -> str:
        """Render a Jinja2 template with the given context.

        Raises:
            jinja2.TemplateNotFound: If the template does not exist.
        """
        template = self._env.get_template(template_name)
        return template.render(**context)
