"""Advisory, report, and alert Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import JsonDecimal

# ── Enums ──


class AlertSeverity(StrEnum):
    """Proactive alert severity levels."""

    INFO = "info"
    WARNING = "warning"
    ACTION = "action"


class BriefingPeriod(StrEnum):
    """CFO briefing period options."""

    WEEKLY = "weekly"
    MONTHLY = "monthly"


# ── Chat ──


class ChatRequest(BaseModel):
    """Inbound chat message from client."""

    message: str = Field(..., min_length=1, max_length=4000)
    conversation_id: uuid.UUID | None = None


class ChatMessage(BaseModel):
    """A single chat message (user or assistant)."""

    role: str = Field(..., max_length=20)  # "user" | "assistant"
    content: str = Field(..., max_length=50000)
    conversation_id: uuid.UUID
    created_at: datetime


# ── Financial Snapshot (context for prompts) ──


class AccountSummary(BaseModel):
    """Lightweight account data for prompt context."""

    account_name: str
    institution_name: str
    account_type: str
    current_balance: JsonDecimal


class DebtSummary(BaseModel):
    """Lightweight debt data for prompt context."""

    debt_name: str
    debt_type: str
    current_balance: JsonDecimal
    interest_rate: JsonDecimal
    minimum_payment: JsonDecimal


class GoalSummary(BaseModel):
    """Lightweight goal data for prompt context."""

    goal_name: str
    goal_type: str
    target_amount: JsonDecimal
    current_amount: JsonDecimal
    target_date: datetime | None = None


class UserFinancialSnapshot(BaseModel):
    """Aggregated financial picture for a user — injected into prompts."""

    user_id: uuid.UUID
    net_worth: JsonDecimal
    total_assets: JsonDecimal
    total_liabilities: JsonDecimal
    annual_income: JsonDecimal | None = None
    monthly_expenses: JsonDecimal | None = None
    filing_status: str = "single"
    risk_tolerance: str = "moderate"
    retirement_age: int = 65
    accounts: list[AccountSummary] = Field(default_factory=list)
    debts: list[DebtSummary] = Field(default_factory=list)
    goals: list[GoalSummary] = Field(default_factory=list)
    health_score: int | None = None


# ── Analysis Results ──


class RetirementAnalysis(BaseModel):
    """Structured retirement analysis from Claude."""

    readiness_score: int = Field(ge=0, le=100)
    projected_shortfall: JsonDecimal
    fire_number: JsonDecimal
    years_to_fire: int | None = None
    recommendations: list[str]
    summary: str


class TaxAnalysis(BaseModel):
    """Structured tax analysis from Claude."""

    estimated_tax_burden: JsonDecimal
    effective_rate: JsonDecimal
    optimization_opportunities: list[str]
    harvesting_candidates: list[str]
    summary: str


class DebtAnalysis(BaseModel):
    """Structured debt strategy analysis from Claude."""

    total_debt: JsonDecimal
    weighted_avg_rate: JsonDecimal
    recommended_strategy: str  # "avalanche" | "snowball" | "hybrid"
    monthly_savings_potential: JsonDecimal
    payoff_timeline_months: int
    recommendations: list[str]
    summary: str


# ── CFO Briefing ──


class BriefingInsight(BaseModel):
    """A single insight in the CFO briefing."""

    title: str
    detail: str
    impact: str  # "positive" | "negative" | "neutral"


class CFOBriefing(BaseModel):
    """Full CFO briefing report."""

    period: BriefingPeriod
    generated_at: datetime
    health_score: int = Field(ge=0, le=100)
    summary: str
    insights: list[BriefingInsight]
    action_items: list[str]
    goal_progress: list[GoalSummary]
    net_worth_change: JsonDecimal


class BriefingSchema(BaseModel):
    """Schema for Claude structured output — narrative portions only."""

    summary: str
    insights: list[BriefingInsight]
    action_items: list[str]


class HealthScoreResponse(BaseModel):
    """Health score with AI narrative explanation."""

    overall_score: int = Field(ge=0, le=100)
    savings_score: int = Field(ge=0, le=100)
    debt_score: int = Field(ge=0, le=100)
    investment_score: int = Field(ge=0, le=100)
    emergency_fund_score: int = Field(ge=0, le=100)
    narrative: str


# ── Proactive Alerts ──


class ProactiveAlert(BaseModel):
    """A proactive financial alert."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    severity: AlertSeverity
    title: str
    message: str
    rule_name: str
    created_at: datetime
