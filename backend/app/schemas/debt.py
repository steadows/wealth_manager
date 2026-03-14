"""Debt Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class DebtCreate(BaseModel):
    """Schema for creating a new debt."""

    account_id: uuid.UUID | None = None
    debt_name: str = Field(..., min_length=1, max_length=200)
    debt_type: str = Field(..., min_length=1, max_length=200)
    original_balance: Decimal = Field(ge=Decimal(0), le=Decimal("999999999999999.9999"))
    current_balance: Decimal = Field(ge=Decimal(0), le=Decimal("999999999999999.9999"))
    interest_rate: Decimal = Field(ge=Decimal(0), le=Decimal("1"))
    minimum_payment: Decimal = Field(ge=Decimal(0), le=Decimal("999999999.9999"))
    payoff_date: datetime | None = None
    is_fixed_rate: bool


class DebtUpdate(BaseModel):
    """Schema for updating a debt."""

    debt_name: str | None = Field(None, min_length=1, max_length=200)
    debt_type: str | None = Field(None, min_length=1, max_length=200)
    current_balance: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999999999.9999"))
    interest_rate: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("1"))
    minimum_payment: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999.9999"))
    payoff_date: datetime | None = None
    is_fixed_rate: bool | None = None


class DebtResponse(BaseModel):
    """Debt response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    account_id: uuid.UUID | None = None
    debt_name: str
    debt_type: str
    original_balance: Decimal
    current_balance: Decimal
    interest_rate: Decimal
    minimum_payment: Decimal
    payoff_date: datetime | None = None
    is_fixed_rate: bool
    created_at: datetime
    updated_at: datetime
