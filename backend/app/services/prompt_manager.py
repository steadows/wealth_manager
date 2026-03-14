"""Prompt template loading and financial context building."""

from decimal import Decimal
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

from app.schemas.advisory import UserFinancialSnapshot


class PromptManager:
    """Loads system prompts and renders Jinja2 templates with financial context."""

    def __init__(self, prompts_dir: Path) -> None:
        self._prompts_dir = prompts_dir
        self._env = Environment(
            loader=FileSystemLoader(str(prompts_dir / "templates")),
            autoescape=select_autoescape(),
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

    def build_financial_context(
        self,
        snapshot: UserFinancialSnapshot,
        *,
        anonymize: bool = False,
    ) -> str:
        """Build a structured text block from a user's financial snapshot.

        Args:
            snapshot: The user's aggregated financial data.
            anonymize: When True, replace account names, institution names, and
                debt names with generic labels (e.g. "Checking Account 1",
                "Institution A", "Debt 1") before the text is sent to an
                external AI API.  Numeric values — balances, rates, payments —
                are always preserved so advice remains accurate.  Goal names
                are kept as-is because they are functional identifiers chosen
                by the user.
        """
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
            # Track per-type counters for stable anonymous labels.
            _acct_type_counts: dict[str, int] = {}
            _institution_map: dict[str, str] = {}
            _institution_counter = [0]  # mutable for closure

            for acct in snapshot.accounts:
                if anonymize:
                    acct_type = acct.account_type.capitalize()
                    _acct_type_counts[acct_type] = _acct_type_counts.get(acct_type, 0) + 1
                    display_name = f"{acct_type} Account {_acct_type_counts[acct_type]}"
                    if acct.institution_name not in _institution_map:
                        _institution_counter[0] += 1
                        label = chr(ord("A") + _institution_counter[0] - 1)
                        _institution_map[acct.institution_name] = f"Institution {label}"
                    display_institution = _institution_map[acct.institution_name]
                else:
                    display_name = acct.account_name
                    display_institution = acct.institution_name

                lines.append(
                    f"- {display_name} ({display_institution}, "
                    f"{acct.account_type}): ${acct.current_balance:,.2f}"
                )

        if snapshot.debts:
            lines.append("")
            lines.append("=== DEBTS ===")
            for idx, debt in enumerate(snapshot.debts, start=1):
                display_name = f"Debt {idx}" if anonymize else debt.debt_name
                rate_pct = debt.interest_rate * 100
                lines.append(
                    f"- {display_name} ({debt.debt_type}): "
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
                # Goal names are kept even when anonymizing — they are functional
                # identifiers selected by the user and needed for coherent advice.
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
