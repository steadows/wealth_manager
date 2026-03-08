"""Debt Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class DebtCreate(BaseModel):
    """Schema for creating a new debt."""

    account_id: uuid.UUID | None = None
    debt_name: str
    debt_type: str
    original_balance: Decimal
    current_balance: Decimal
    interest_rate: Decimal
    minimum_payment: Decimal
    payoff_date: datetime | None = None
    is_fixed_rate: bool


class DebtUpdate(BaseModel):
    """Schema for updating a debt."""

    debt_name: str | None = None
    debt_type: str | None = None
    current_balance: Decimal | None = None
    interest_rate: Decimal | None = None
    minimum_payment: Decimal | None = None
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
