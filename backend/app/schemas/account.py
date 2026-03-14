"""Account Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import AccountType


class AccountCreate(BaseModel):
    """Schema for creating a new account."""

    institution_name: str = Field(..., min_length=1, max_length=200)
    account_name: str = Field(..., min_length=1, max_length=200)
    account_type: AccountType
    current_balance: Decimal = Field(
        ...,
        ge=Decimal("-999999999999999.9999"),
        le=Decimal("999999999999999.9999"),
    )
    available_balance: Decimal | None = Field(
        default=None,
        ge=Decimal("-999999999999999.9999"),
        le=Decimal("999999999999999.9999"),
    )
    currency: str = "USD"
    is_manual: bool = True


class AccountUpdate(BaseModel):
    """Schema for updating an account."""

    institution_name: str | None = Field(None, min_length=1, max_length=200)
    account_name: str | None = Field(None, min_length=1, max_length=200)
    account_type: AccountType | None = None
    current_balance: Decimal | None = Field(
        default=None,
        ge=Decimal("-999999999999999.9999"),
        le=Decimal("999999999999999.9999"),
    )
    available_balance: Decimal | None = Field(
        default=None,
        ge=Decimal("-999999999999999.9999"),
        le=Decimal("999999999999999.9999"),
    )
    currency: str | None = None
    is_hidden: bool | None = None


class AccountResponse(BaseModel):
    """Account response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    plaid_account_id: str | None = None
    institution_name: str
    account_name: str
    account_type: str
    current_balance: Decimal
    available_balance: Decimal | None = None
    currency: str
    is_manual: bool
    is_hidden: bool
    last_synced_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
