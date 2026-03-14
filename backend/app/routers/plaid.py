"""Plaid integration endpoints — link-token, exchange-token, sync."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.dependencies import get_current_user, get_db
from app.models.account import Account
from app.repositories.account_repository import AccountRepository
from app.schemas.account import AccountResponse
from app.schemas.plaid import (
    PlaidExchangeRequest,
    PlaidExchangeResponse,
    PlaidLinkResponse,
    SandboxFireWebhookRequest,
    SandboxFireWebhookResponse,
    SandboxPublicTokenRequest,
    SandboxPublicTokenResponse,
    SandboxResetLoginRequest,
    SandboxResetLoginResponse,
)
from app.services.plaid_service import PlaidService, get_plaid_service

router = APIRouter(prefix="/plaid", tags=["plaid"])

# Map Plaid account types to our AccountType enum values
_PLAID_TYPE_MAP = {
    "depository": "checking",
    "credit": "creditCard",
    "loan": "loan",
    "investment": "investment",
    "other": "other",
}

_PLAID_SUBTYPE_MAP = {
    "checking": "checking",
    "savings": "savings",
    "credit card": "creditCard",
    "401k": "retirement",
    "ira": "retirement",
    "roth": "retirement",
    "student": "loan",
    "mortgage": "loan",
    "auto": "loan",
}


def _map_plaid_account_type(acct_type: str, subtype: str | None) -> str:
    """Map Plaid account type/subtype to our AccountType enum value."""
    if subtype and subtype in _PLAID_SUBTYPE_MAP:
        return _PLAID_SUBTYPE_MAP[subtype]
    return _PLAID_TYPE_MAP.get(acct_type, "other")


@router.post("/link-token", response_model=PlaidLinkResponse)
async def create_link_token(
    user_id: uuid.UUID = Depends(get_current_user),
    plaid: PlaidService = Depends(get_plaid_service),
) -> PlaidLinkResponse:
    """Create a Plaid Link token for the authenticated user."""
    link_token = plaid.create_link_token(user_id)
    return PlaidLinkResponse(link_token=link_token)


@router.post("/exchange-token", response_model=PlaidExchangeResponse)
async def exchange_token(
    body: PlaidExchangeRequest,
    user_id: uuid.UUID = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    plaid: PlaidService = Depends(get_plaid_service),
) -> PlaidExchangeResponse:
    """Exchange a Plaid public token and create Account records.

    Calls Plaid to exchange the public_token for an access_token,
    fetches account data, and persists Account records.
    """
    access_token, item_id = plaid.exchange_public_token(body.public_token)
    plaid_accounts = plaid.get_accounts(access_token)

    repo = AccountRepository(db)
    created_accounts: list[Account] = []
    now = datetime.now(UTC)

    for plaid_acct in plaid_accounts:
        balances = plaid_acct.get("balances", {})
        account = Account(
            id=uuid.uuid4(),
            user_id=user_id,
            plaid_account_id=plaid_acct.get("account_id", ""),
            plaid_access_token=access_token,
            plaid_item_id=item_id,
            institution_name=plaid_acct.get("official_name") or plaid_acct.get("name", "Unknown"),
            account_name=plaid_acct.get("name", "Unknown"),
            account_type=_map_plaid_account_type(
                plaid_acct.get("type", "other"),
                plaid_acct.get("subtype"),
            ),
            current_balance=Decimal(str(balances.get("current", 0))),
            available_balance=(
                Decimal(str(balances["available"]))
                if balances.get("available") is not None
                else None
            ),
            currency="USD",
            is_manual=False,
            created_at=now,
            updated_at=now,
        )
        created = await repo.create(account)
        created_accounts.append(created)

    return PlaidExchangeResponse(
        accounts=[AccountResponse.model_validate(a) for a in created_accounts]
    )


@router.post("/sync/{account_id}")
async def sync_account(
    account_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    plaid: PlaidService = Depends(get_plaid_service),
) -> dict:
    """Trigger a transaction sync for a specific Plaid-linked account.

    Returns counts of added, modified, and removed transactions.
    """
    repo = AccountRepository(db)
    account = await repo.get_by_id(account_id)

    if account is None or account.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    if not account.plaid_access_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not linked to Plaid",
        )

    result = plaid.sync_transactions(
        account.plaid_access_token,
        cursor=account.plaid_cursor,
    )

    # Update cursor on the account
    await repo.update(
        account,
        {
            "plaid_cursor": result["next_cursor"],
            "last_synced_at": datetime.now(UTC),
            "updated_at": datetime.now(UTC),
        },
    )

    return {
        "added_count": len(result["added"]),
        "modified_count": len(result["modified"]),
        "removed_count": len(result["removed"]),
        "has_more": result["has_more"],
    }


@router.post(
    "/sandbox/public-token",
    response_model=SandboxPublicTokenResponse,
    status_code=201,
)
async def create_sandbox_public_token(
    body: SandboxPublicTokenRequest = SandboxPublicTokenRequest(),
    plaid: PlaidService = Depends(get_plaid_service),
) -> SandboxPublicTokenResponse:
    """Create a Plaid public token via the sandbox API (sandbox only).

    Bypasses Link UI for integration testing. Returns a public_token
    that can be exchanged via /exchange-token.
    """
    settings = get_settings()
    if settings.plaid_env != "sandbox":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only available in the sandbox environment",
        )

    public_token = plaid.create_sandbox_public_token(
        institution_id=body.institution_id,
        initial_products=body.initial_products,
    )
    return SandboxPublicTokenResponse(public_token=public_token)


@router.post(
    "/sandbox/fire-webhook",
    response_model=SandboxFireWebhookResponse,
)
async def fire_sandbox_webhook(
    body: SandboxFireWebhookRequest,
    plaid: PlaidService = Depends(get_plaid_service),
) -> SandboxFireWebhookResponse:
    """Fire a Plaid sandbox webhook (sandbox only).

    Triggers a webhook event for the given item, useful for
    integration testing webhook handling flows.
    """
    settings = get_settings()
    if settings.plaid_env != "sandbox":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only available in the sandbox environment",
        )

    result = plaid.fire_sandbox_webhook(
        access_token=body.access_token,
        webhook_code=body.webhook_code,
    )
    return SandboxFireWebhookResponse(webhook_fired=result["webhook_fired"])


@router.post(
    "/sandbox/reset-login",
    response_model=SandboxResetLoginResponse,
)
async def reset_sandbox_login(
    body: SandboxResetLoginRequest,
    plaid: PlaidService = Depends(get_plaid_service),
) -> SandboxResetLoginResponse:
    """Reset a sandbox item's login credentials (sandbox only).

    Forces the item into ITEM_LOGIN_REQUIRED state for testing
    the re-authentication flow.
    """
    settings = get_settings()
    if settings.plaid_env != "sandbox":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only available in the sandbox environment",
        )

    result = plaid.reset_sandbox_login(access_token=body.access_token)
    return SandboxResetLoginResponse(reset_login=result["reset_login"])
