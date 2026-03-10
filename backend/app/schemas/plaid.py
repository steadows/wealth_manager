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
