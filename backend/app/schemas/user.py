"""User and UserProfile Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class UserResponse(BaseModel):
    """User response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None = None
    created_at: datetime
    updated_at: datetime


class UserProfileUpdate(BaseModel):
    """Schema for updating a user profile."""

    date_of_birth: datetime | None = None
    annual_income: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999999999.9999"))
    monthly_expenses: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999999999.9999"))
    filing_status: str | None = Field(default=None, max_length=50)
    state_of_residence: str | None = Field(default=None, max_length=50)
    retirement_age: int | None = Field(default=None, ge=18, le=100)
    risk_tolerance: str | None = Field(default=None, max_length=50)
    dependents: int | None = Field(default=None, ge=0, le=50)
    has_spouse: bool | None = None
    spouse_income: Decimal | None = Field(default=None, ge=Decimal(0), le=Decimal("999999999999999.9999"))


class UserProfileResponse(BaseModel):
    """UserProfile response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    date_of_birth: datetime | None = None
    annual_income: Decimal | None = None
    monthly_expenses: Decimal | None = None
    filing_status: str
    state_of_residence: str | None = None
    retirement_age: int
    risk_tolerance: str
    dependents: int
    has_spouse: bool
    spouse_income: Decimal | None = None
    created_at: datetime
    updated_at: datetime
