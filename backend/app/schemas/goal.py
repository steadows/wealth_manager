"""FinancialGoal Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class GoalCreate(BaseModel):
    """Schema for creating a new financial goal."""

    goal_name: str
    goal_type: str
    target_amount: Decimal
    current_amount: Decimal = Decimal(0)
    target_date: datetime | None = None
    monthly_contribution: Decimal | None = None
    priority: int
    is_active: bool = True
    notes: str | None = None


class GoalUpdate(BaseModel):
    """Schema for updating a financial goal."""

    goal_name: str | None = None
    goal_type: str | None = None
    target_amount: Decimal | None = None
    current_amount: Decimal | None = None
    target_date: datetime | None = None
    monthly_contribution: Decimal | None = None
    priority: int | None = None
    is_active: bool | None = None
    notes: str | None = None


class GoalResponse(BaseModel):
    """FinancialGoal response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    goal_name: str
    goal_type: str
    target_amount: Decimal
    current_amount: Decimal
    target_date: datetime | None = None
    monthly_contribution: Decimal | None = None
    priority: int
    is_active: bool
    notes: str | None = None
    created_at: datetime
    updated_at: datetime
