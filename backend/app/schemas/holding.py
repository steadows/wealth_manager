"""InvestmentHolding Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class HoldingCreate(BaseModel):
    """Schema for creating a new investment holding."""

    account_id: uuid.UUID
    security_name: str
    ticker_symbol: str | None = None
    quantity: Decimal
    cost_basis: Decimal | None = None
    current_price: Decimal
    holding_type: str
    asset_class: str
    purchase_date: datetime | None = None


class HoldingUpdate(BaseModel):
    """Schema for updating an investment holding."""

    security_name: str | None = None
    ticker_symbol: str | None = None
    quantity: Decimal | None = None
    cost_basis: Decimal | None = None
    current_price: Decimal | None = None
    holding_type: str | None = None
    asset_class: str | None = None
    purchase_date: datetime | None = None


class HoldingResponse(BaseModel):
    """InvestmentHolding response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    account_id: uuid.UUID
    security_name: str
    ticker_symbol: str | None = None
    quantity: Decimal
    cost_basis: Decimal | None = None
    current_price: Decimal
    holding_type: str
    asset_class: str
    purchase_date: datetime | None = None
    last_price_update: datetime
