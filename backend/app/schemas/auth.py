"""Authentication Pydantic schemas (Sprint 3 stubs)."""

from pydantic import BaseModel


class LoginRequest(BaseModel):
    """Apple Sign-In token exchange request."""

    identity_token: str


class LoginResponse(BaseModel):
    """Login response with JWT tokens."""

    access_token: str
    token_type: str = "bearer"


class TokenResponse(BaseModel):
    """JWT token refresh response."""

    access_token: str
    token_type: str = "bearer"
