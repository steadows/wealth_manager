"""Report service — CFO briefing and health score generation."""

from datetime import UTC, datetime
from decimal import Decimal

from app.schemas.advisory import (
    BriefingPeriod,
    BriefingSchema,
    CFOBriefing,
    HealthScoreResponse,
    UserFinancialSnapshot,
)
from app.services.claude_service import ClaudeService
from app.services.prompt_manager import PromptManager


class ReportService:
    """Generates CFO briefings and health score reports using Claude."""

    def __init__(
        self,
        claude_service: ClaudeService,
        prompt_manager: PromptManager,
    ) -> None:
        self._claude = claude_service
        self._prompts = prompt_manager

    async def generate_briefing(
        self,
        *,
        snapshot: UserFinancialSnapshot,
        period: BriefingPeriod,
        net_worth_change: Decimal,
    ) -> CFOBriefing:
        """Generate a weekly or monthly CFO briefing."""
        system_prompt = self._prompts.load_system_prompt("report_generator")

        prompt = self._prompts.render_prompt(
            "weekly_briefing.jinja2",
            {
                "period": period.value,
                "snapshot": snapshot,
                "calculations": {
                    "net_worth_change": net_worth_change,
                    "net_worth_change_pct": (
                        float(net_worth_change / snapshot.net_worth * 100)
                        if snapshot.net_worth != 0
                        else 0.0
                    ),
                    "top_spending_categories": [],
                    "alerts": [],
                },
            },
        )

        narrative = await self._claude.structured_generate(
            system_prompt=system_prompt,
            user_message=prompt,
            output_schema=BriefingSchema,
        )

        return CFOBriefing(
            period=period,
            generated_at=datetime.now(UTC),
            health_score=snapshot.health_score or 0,
            summary=narrative.summary,
            insights=narrative.insights,
            action_items=narrative.action_items,
            goal_progress=list(snapshot.goals),
            net_worth_change=net_worth_change,
        )

    async def generate_health_score(
        self,
        *,
        snapshot: UserFinancialSnapshot,
        scores: dict[str, int],
    ) -> HealthScoreResponse:
        """Generate a health score response with AI narrative explanation."""
        context = self._prompts.build_financial_context(snapshot)
        system_prompt = self._prompts.load_system_prompt("financial_advisor")

        score_summary = (
            f"Overall: {scores['overall']}/100, "
            f"Savings: {scores['savings']}/100, "
            f"Debt: {scores['debt']}/100, "
            f"Investment: {scores['investment']}/100, "
            f"Emergency Fund: {scores['emergency_fund']}/100"
        )

        narrative = await self._claude.generate(
            system_prompt=system_prompt,
            user_message=(
                f"<financial_data>\n{context}\n</financial_data>\n\n"
                "<user_question>\n"
                f"Explain this financial health score breakdown in 2-3 sentences. "
                f"Be specific about what's strong and what needs work.\n\n"
                f"Scores: {score_summary}"
                "\n</user_question>"
            ),
        )

        return HealthScoreResponse(
            overall_score=scores["overall"],
            savings_score=scores["savings"],
            debt_score=scores["debt"],
            investment_score=scores["investment"],
            emergency_fund_score=scores["emergency_fund"],
            narrative=narrative,
        )
