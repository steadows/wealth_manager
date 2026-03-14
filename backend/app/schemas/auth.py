"""Authentication Pydantic schemas."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class LoginRequest(BaseModel):
    """Apple Sign-In token exchange request."""

    identity_token: str = Field(..., min_length=1, max_length=5000)


class LoginResponse(BaseModel):
    """Login response with JWT tokens."""

    access_token: str
    token_type: str = "bearer"


class TokenResponse(BaseModel):
    """JWT token refresh response."""

    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    """Authenticated user info response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None = None
    created_at: datetime
