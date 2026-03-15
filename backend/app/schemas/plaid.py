"""Plaid integration Pydantic schemas."""

from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.account import AccountResponse


class PlaidLinkRequest(BaseModel):
    """Request to create a Plaid link token."""

    pass


class PlaidLinkResponse(BaseModel):
    """Response containing a Plaid link token."""

    link_token: str


class PlaidExchangeRequest(BaseModel):
    """Request to exchange a Plaid public token."""

    public_token: str = Field(..., min_length=1, max_length=500)


class PlaidExchangeResponse(BaseModel):
    """Response after exchanging a Plaid public token."""

    accounts: list[AccountResponse]


class SandboxPublicTokenRequest(BaseModel):
    """Request to create a sandbox public token (sandbox only)."""

    institution_id: str = Field(default="ins_109508", max_length=100)
    initial_products: list[str] = ["transactions"]


class SandboxPublicTokenResponse(BaseModel):
    """Response containing a sandbox public token."""

    public_token: str


class SandboxFireWebhookRequest(BaseModel):
    """Request to fire a sandbox webhook."""

    access_token: str = Field(..., max_length=500)
    webhook_code: str = Field(default="SYNC_UPDATES_AVAILABLE", max_length=100)


class SandboxFireWebhookResponse(BaseModel):
    """Response after firing a sandbox webhook."""

    webhook_fired: bool


class SandboxResetLoginRequest(BaseModel):
    """Request to reset a sandbox item's login credentials."""

    access_token: str = Field(..., max_length=500)


class SandboxResetLoginResponse(BaseModel):
    """Response after resetting sandbox login."""

    reset_login: bool


class HostedLinkTokenResponse(BaseModel):
    """Response containing a hosted Plaid Link token and URL."""

    link_token: str
    hosted_link_url: str


class ResolveSessionRequest(BaseModel):
    """Request to resolve a Plaid Hosted Link session."""

    link_token: str = Field(..., min_length=1, max_length=500)


class ResolveSessionResponse(BaseModel):
    """Response from resolving a Plaid Hosted Link session.

    status is one of: complete, pending, exited, expired, unknown.
    accounts is populated only when status is 'complete'.
    """

    status: str
    accounts: list[AccountResponse] | None = None
