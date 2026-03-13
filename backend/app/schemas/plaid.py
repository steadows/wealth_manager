"""Plaid integration Pydantic schemas."""

from __future__ import annotations

from pydantic import BaseModel

from app.schemas.account import AccountResponse


class PlaidLinkRequest(BaseModel):
    """Request to create a Plaid link token."""

    pass


class PlaidLinkResponse(BaseModel):
    """Response containing a Plaid link token."""

    link_token: str


class PlaidExchangeRequest(BaseModel):
    """Request to exchange a Plaid public token."""

    public_token: str


class PlaidExchangeResponse(BaseModel):
    """Response after exchanging a Plaid public token."""

    accounts: list[AccountResponse]


class SandboxPublicTokenRequest(BaseModel):
    """Request to create a sandbox public token (sandbox only)."""

    institution_id: str = "ins_109508"
    initial_products: list[str] = ["transactions"]


class SandboxPublicTokenResponse(BaseModel):
    """Response containing a sandbox public token."""

    public_token: str


class SandboxFireWebhookRequest(BaseModel):
    """Request to fire a sandbox webhook."""

    access_token: str
    webhook_code: str = "SYNC_UPDATES_AVAILABLE"


class SandboxFireWebhookResponse(BaseModel):
    """Response after firing a sandbox webhook."""

    webhook_fired: bool


class SandboxResetLoginRequest(BaseModel):
    """Request to reset a sandbox item's login credentials."""

    access_token: str


class SandboxResetLoginResponse(BaseModel):
    """Response after resetting sandbox login."""

    reset_login: bool
