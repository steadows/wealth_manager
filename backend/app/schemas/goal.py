"""FinancialGoal Pydantic schemas with validation.

Adds GoalPriority enum, input validation (positive target_amount,
non-empty name, future target_date), and GoalType enum enforcement.
"""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.enums import GoalPriority, GoalType


class GoalCreate(BaseModel):
    """Schema for creating a new financial goal.

    Validates:
    - goal_name is non-empty
    - goal_type is a valid GoalType enum value
    - target_amount is positive (> 0)
    - target_date, if provided, is in the future
    - priority is a valid GoalPriority enum value
    """

    goal_name: str = Field(..., max_length=200)
    goal_type: GoalType
    target_amount: Decimal = Field(..., le=Decimal("999999999999999.9999"))
    current_amount: Decimal = Field(default=Decimal(0), ge=Decimal(0), le=Decimal("999999999999999.9999"))
    target_date: datetime | None = None
    monthly_contribution: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999.9999"))
    priority: GoalPriority
    is_active: bool = True
    notes: str | None = Field(None, max_length=2000)

    @field_validator("goal_name")
    @classmethod
    def goal_name_not_empty(cls, v: str) -> str:
        """Reject empty or whitespace-only goal names."""
        if not v or not v.strip():
            raise ValueError("goal_name must not be empty")
        return v.strip()

    @field_validator("target_amount")
    @classmethod
    def target_amount_positive(cls, v: Decimal) -> Decimal:
        """Reject zero or negative target amounts."""
        if v <= 0:
            raise ValueError("target_amount must be positive")
        return v

    @field_validator("target_date")
    @classmethod
    def target_date_in_future(cls, v: datetime | None) -> datetime | None:
        """Reject target dates that are in the past."""
        if v is not None and v < datetime.now(UTC):
            raise ValueError("target_date must be in the future")
        return v


class GoalUpdate(BaseModel):
    """Schema for updating a financial goal."""

    goal_name: str | None = Field(None, max_length=200)
    goal_type: GoalType | None = None
    target_amount: Decimal | None = Field(default=None, le=Decimal("999999999999999.9999"))
    current_amount: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999999999.9999"))
    target_date: datetime | None = None
    monthly_contribution: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999.9999"))
    priority: GoalPriority | None = None
    is_active: bool | None = None
    notes: str | None = Field(None, max_length=2000)

    @field_validator("goal_name")
    @classmethod
    def goal_name_not_empty(cls, v: str | None) -> str | None:
        """Reject empty or whitespace-only goal names."""
        if v is not None:
            if not v.strip():
                raise ValueError("goal_name must not be empty")
            return v.strip()
        return v

    @field_validator("target_amount")
    @classmethod
    def target_amount_positive(cls, v: Decimal | None) -> Decimal | None:
        """Reject zero or negative target amounts."""
        if v is not None and v <= 0:
            raise ValueError("target_amount must be positive")
        return v

    @field_validator("target_date")
    @classmethod
    def target_date_in_future(cls, v: datetime | None) -> datetime | None:
        """Reject target dates that are in the past."""
        if v is not None and v < datetime.now(UTC):
            raise ValueError("target_date must be in the future")
        return v


class GoalResponse(BaseModel):
    """FinancialGoal response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    goal_name: str
    goal_type: GoalType
    target_amount: Decimal
    current_amount: Decimal
    target_date: datetime | None = None
    monthly_contribution: Decimal | None = None
    priority: GoalPriority
    is_active: bool
    notes: str | None = None
    created_at: datetime
    updated_at: datetime
