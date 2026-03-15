"""Advisory, reports, and alerts API endpoints."""

import json
import uuid
from decimal import Decimal
from pathlib import Path

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.dependencies import get_current_user, get_db
from app.schemas.advisory import (
    AccountSummary,
    BriefingPeriod,
    CFOBriefing,
    ChatRequest,
    DebtAnalysis,
    DebtSummary,
    GoalSummary,
    HealthScoreResponse,
    ProactiveAlert,
    RetirementAnalysis,
    TaxAnalysis,
    UserFinancialSnapshot,
)
from app.schemas.common import APIResponse
from app.services.advisory_service import AdvisoryService
from app.services.alert_service import AlertService
from app.services.claude_service import ClaudeService
from app.services.prompt_manager import PromptManager
from app.services.report_service import ReportService

_PROMPTS_DIR = Path(__file__).parent.parent / "prompts"

router = APIRouter(tags=["advisory"])


# ── Dependency factories ──


def get_claude_service(settings: Settings = Depends(get_settings)) -> ClaudeService:
    """Create a ClaudeService from app settings."""
    return ClaudeService(settings)


def get_prompt_manager() -> PromptManager:
    """Create a PromptManager with the prompts directory."""
    return PromptManager(_PROMPTS_DIR)


def get_advisory_service(
    claude: ClaudeService = Depends(get_claude_service),
    prompts: PromptManager = Depends(get_prompt_manager),
) -> AdvisoryService:
    """Create an AdvisoryService."""
    return AdvisoryService(claude_service=claude, prompt_manager=prompts)


def get_report_service(
    claude: ClaudeService = Depends(get_claude_service),
    prompts: PromptManager = Depends(get_prompt_manager),
) -> ReportService:
    """Create a ReportService."""
    return ReportService(claude_service=claude, prompt_manager=prompts)


def get_alert_service() -> AlertService:
    """Create an AlertService."""
    return AlertService()


async def build_snapshot(
    user_id: uuid.UUID,
    db: AsyncSession,
) -> UserFinancialSnapshot:
    """Build a UserFinancialSnapshot from the database.

    Queries accounts, debts, goals, and profile for the given user.
    """
    from sqlalchemy import select

    from app.models.account import Account
    from app.models.debt import Debt
    from app.models.goal import FinancialGoal
    from app.models.user import UserProfile

    # Fetch accounts
    result = await db.execute(
        select(Account).where(Account.user_id == user_id, Account.is_hidden == False)  # noqa: E712
    )
    accounts = result.scalars().all()

    # Fetch debts
    result = await db.execute(select(Debt).where(Debt.user_id == user_id))
    debts = result.scalars().all()

    # Fetch goals
    result = await db.execute(
        select(FinancialGoal).where(
            FinancialGoal.user_id == user_id,
            FinancialGoal.is_active == True,  # noqa: E712
        )
    )
    goals = result.scalars().all()

    # Fetch profile
    result = await db.execute(select(UserProfile).where(UserProfile.user_id == user_id))
    profile = result.scalars().first()

    # Aggregate
    total_assets = sum((a.current_balance for a in accounts if a.is_asset), Decimal(0))
    total_liabilities = sum(
        (a.current_balance for a in accounts if a.is_liability), Decimal(0)
    ) + sum((d.current_balance for d in debts), Decimal(0))

    return UserFinancialSnapshot(
        user_id=user_id,
        net_worth=total_assets - total_liabilities,
        total_assets=total_assets,
        total_liabilities=total_liabilities,
        annual_income=profile.annual_income if profile else None,
        monthly_expenses=profile.monthly_expenses if profile else None,
        filing_status=profile.filing_status if profile else "single",
        risk_tolerance=profile.risk_tolerance if profile else "moderate",
        retirement_age=profile.retirement_age if profile else 65,
        accounts=[
            AccountSummary(
                account_name=a.account_name,
                institution_name=a.institution_name,
                account_type=a.account_type,
                current_balance=a.current_balance,
            )
            for a in accounts
        ],
        debts=[
            DebtSummary(
                debt_name=d.debt_name,
                debt_type=d.debt_type,
                current_balance=d.current_balance,
                interest_rate=d.interest_rate,
                minimum_payment=d.minimum_payment,
            )
            for d in debts
        ],
        goals=[
            GoalSummary(
                goal_name=g.goal_name,
                goal_type=g.goal_type,
                target_amount=g.target_amount,
                current_amount=g.current_amount,
                target_date=g.target_date,
            )
            for g in goals
        ],
    )


# ── Endpoints ──


@router.post("/advisor/chat")
async def advisor_chat(
    data: ChatRequest,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: AdvisoryService = Depends(get_advisory_service),
) -> StreamingResponse:
    """Stream an AI advisory chat response via SSE."""
    snapshot = await build_snapshot(user_id, db)

    async def event_stream():
        async for chunk in service.chat(
            snapshot=snapshot,
            user_message=data.message,
        ):
            # JSON-encode the chunk so newlines are safely escaped as \n
            # within a single data: line. The iOS client JSON-decodes to restore them.
            yield f"data: {json.dumps(chunk)}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/reports/briefing", response_model=APIResponse[CFOBriefing])
async def get_briefing(
    period: BriefingPeriod = Query(default=BriefingPeriod.WEEKLY),
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: ReportService = Depends(get_report_service),
) -> APIResponse[CFOBriefing]:
    """Generate a CFO briefing report."""
    snapshot = await build_snapshot(user_id, db)
    briefing = await service.generate_briefing(
        snapshot=snapshot,
        period=period,
        net_worth_change=Decimal("0"),  # TODO: compute from snapshots
    )
    return APIResponse(data=briefing)


@router.get("/reports/health-score", response_model=APIResponse[HealthScoreResponse])
async def get_health_score(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: ReportService = Depends(get_report_service),
) -> APIResponse[HealthScoreResponse]:
    """Get the current financial health score with AI narrative."""
    snapshot = await build_snapshot(user_id, db)
    # TODO: compute real scores from HealthScoreCalculator
    scores = {
        "overall": snapshot.health_score or 50,
        "savings": 50,
        "debt": 50,
        "investment": 50,
        "emergency_fund": 50,
    }
    result = await service.generate_health_score(snapshot=snapshot, scores=scores)
    return APIResponse(data=result)


@router.get("/alerts", response_model=APIResponse[list[ProactiveAlert]])
async def get_alerts(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: AlertService = Depends(get_alert_service),
) -> APIResponse[list[ProactiveAlert]]:
    """Fetch proactive financial alerts."""
    snapshot = await build_snapshot(user_id, db)
    alerts = service.check_alerts(
        snapshot=snapshot,
        previous_net_worth=snapshot.net_worth,  # TODO: fetch previous from snapshots
        spending_by_category={},
        average_spending_by_category={},
        current_savings_rate=Decimal("0.15"),  # TODO: compute real rate
        previous_savings_rate=Decimal("0.15"),
        current_month=snapshot.goals[0].target_date.month if snapshot.goals else 1,
    )
    return APIResponse(data=alerts)


@router.post(
    "/advisor/analyze/retirement",
    response_model=APIResponse[RetirementAnalysis],
)
async def analyze_retirement(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: AdvisoryService = Depends(get_advisory_service),
) -> APIResponse[RetirementAnalysis]:
    """Generate a full retirement analysis."""
    snapshot = await build_snapshot(user_id, db)
    result = await service.analyze_retirement(snapshot=snapshot)
    return APIResponse(data=result)


@router.post(
    "/advisor/analyze/tax",
    response_model=APIResponse[TaxAnalysis],
)
async def analyze_tax(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: AdvisoryService = Depends(get_advisory_service),
) -> APIResponse[TaxAnalysis]:
    """Generate tax optimization suggestions."""
    snapshot = await build_snapshot(user_id, db)
    result = await service.analyze_tax(snapshot=snapshot)
    return APIResponse(data=result)


@router.post(
    "/advisor/analyze/debt",
    response_model=APIResponse[DebtAnalysis],
)
async def analyze_debt(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
    service: AdvisoryService = Depends(get_advisory_service),
) -> APIResponse[DebtAnalysis]:
    """Generate debt strategy recommendations."""
    snapshot = await build_snapshot(user_id, db)
    result = await service.analyze_debt(snapshot=snapshot)
    return APIResponse(data=result)
