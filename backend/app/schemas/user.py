"""User and UserProfile Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class UserResponse(BaseModel):
    """User response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    apple_id: str
    email: str | None = None
    created_at: datetime
    updated_at: datetime


class UserProfileUpdate(BaseModel):
    """Schema for updating a user profile."""

    date_of_birth: datetime | None = None
    annual_income: Decimal | None = None
    monthly_expenses: Decimal | None = None
    filing_status: str | None = None
    state_of_residence: str | None = None
    retirement_age: int | None = None
    risk_tolerance: str | None = None
    dependents: int | None = None
    has_spouse: bool | None = None
    spouse_income: Decimal | None = None


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
