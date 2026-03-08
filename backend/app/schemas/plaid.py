"""Plaid integration Pydantic schemas (Sprint 3 stubs)."""

from pydantic import BaseModel


class PlaidLinkRequest(BaseModel):
    """Request to create a Plaid link token."""

    pass


class PlaidLinkResponse(BaseModel):
    """Response containing a Plaid link token."""

    link_token: str
