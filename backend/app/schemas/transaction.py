"""Transaction Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import JsonDecimal


class TransactionCreate(BaseModel):
    """Schema for creating a new transaction."""

    account_id: uuid.UUID
    amount: Decimal = Field(
        ...,
        ge=Decimal("-999999999999999.9999"),
        le=Decimal("999999999999999.9999"),
    )
    date: datetime
    merchant_name: str | None = Field(default=None, max_length=200)
    category: str = Field(..., min_length=1, max_length=100)
    subcategory: str | None = Field(default=None, max_length=100)
    note: str | None = Field(default=None, max_length=2000)
    is_recurring: bool = False
    is_pending: bool = False


class TransactionUpdate(BaseModel):
    """Schema for updating a transaction."""

    amount: Decimal | None = Field(
        default=None,
        ge=Decimal("-999999999999999.9999"),
        le=Decimal("999999999999999.9999"),
    )
    date: datetime | None = None
    merchant_name: str | None = Field(default=None, max_length=200)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    subcategory: str | None = Field(default=None, max_length=100)
    note: str | None = Field(default=None, max_length=2000)
    is_recurring: bool | None = None
    is_pending: bool | None = None


class TransactionResponse(BaseModel):
    """Transaction response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    account_id: uuid.UUID
    plaid_transaction_id: str | None = None
    amount: JsonDecimal
    date: datetime
    merchant_name: str | None = None
    category: str
    subcategory: str | None = None
    note: str | None = None
    is_recurring: bool
    is_pending: bool
    created_at: datetime


class TransactionListResponse(BaseModel):
    """Paginated list of transactions for an account."""

    transactions: list[TransactionResponse]
    total: int
    limit: int
    offset: int
