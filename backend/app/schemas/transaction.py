"""Transaction Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class TransactionCreate(BaseModel):
    """Schema for creating a new transaction."""

    account_id: uuid.UUID
    amount: Decimal
    date: datetime
    merchant_name: str | None = None
    category: str
    subcategory: str | None = None
    note: str | None = None
    is_recurring: bool = False
    is_pending: bool = False


class TransactionUpdate(BaseModel):
    """Schema for updating a transaction."""

    amount: Decimal | None = None
    date: datetime | None = None
    merchant_name: str | None = None
    category: str | None = None
    subcategory: str | None = None
    note: str | None = None
    is_recurring: bool | None = None
    is_pending: bool | None = None


class TransactionResponse(BaseModel):
    """Transaction response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    account_id: uuid.UUID
    plaid_transaction_id: str | None = None
    amount: Decimal
    date: datetime
    merchant_name: str | None = None
    category: str
    subcategory: str | None = None
    note: str | None = None
    is_recurring: bool
    is_pending: bool
    created_at: datetime
