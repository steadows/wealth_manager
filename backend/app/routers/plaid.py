"""Plaid integration endpoints — link-token, exchange-token, sync."""

from __future__ import annotations

import logging
import time
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.dependencies import get_current_user, get_db
from app.models.account import Account
from app.models.transaction import Transaction
from app.utils.encryption import encrypt_value, decrypt_value
from app.repositories.account_repository import AccountRepository
from app.repositories.transaction_repository import TransactionRepository
from app.schemas.account import AccountResponse
from app.schemas.plaid import (
    HostedLinkTokenResponse,
    PlaidExchangeRequest,
    PlaidExchangeResponse,
    PlaidLinkResponse,
    ResolveSessionRequest,
    ResolveSessionResponse,
    SandboxFireWebhookRequest,
    SandboxFireWebhookResponse,
    SandboxPublicTokenRequest,
    SandboxPublicTokenResponse,
    SandboxResetLoginRequest,
    SandboxResetLoginResponse,
)
from app.services.plaid_service import PlaidService, get_plaid_service
from app.utils.security_logger import log_token_exchange

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/plaid", tags=["plaid"])

# In-memory link token ownership cache (link_token -> (user_id, created_at))
# Link tokens expire after 30 minutes; entries cleaned on access.
_link_token_owners: dict[str, tuple[uuid.UUID, float]] = {}
_LINK_TOKEN_TTL = 1800  # 30 minutes

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


# Map Plaid personal_finance_category.primary to our TransactionCategory
_PLAID_CATEGORY_MAP = {
    "INCOME": "income",
    "TRANSFER_IN": "transfer",
    "TRANSFER_OUT": "transfer",
    "LOAN_PAYMENTS": "fees",
    "BANK_FEES": "fees",
    "ENTERTAINMENT": "entertainment",
    "FOOD_AND_DRINK": "food",
    "GENERAL_MERCHANDISE": "shopping",
    "HOME_IMPROVEMENT": "housing",
    "MEDICAL": "healthcare",
    "PERSONAL_CARE": "personalCare",
    "GENERAL_SERVICES": "other",
    "GOVERNMENT_AND_NON_PROFIT": "other",
    "TRANSPORTATION": "transportation",
    "TRAVEL": "travel",
    "RENT_AND_UTILITIES": "utilities",
}


def _map_plaid_category(plaid_txn: dict) -> str:
    """Map a Plaid transaction's category to our TransactionCategory value."""
    pfc = plaid_txn.get("personal_finance_category") or {}
    primary = pfc.get("primary", "") if isinstance(pfc, dict) else ""
    return _PLAID_CATEGORY_MAP.get(primary, "other")


async def _store_synced_transactions(
    plaid_txns: list[dict],
    account_id: uuid.UUID,
    txn_repo: TransactionRepository,
    plaid_account_id: str | None = None,
) -> int:
    """Persist Plaid transaction dicts as Transaction records.

    Skips transactions that already exist (by plaid_transaction_id).
    When plaid_account_id is provided, only stores transactions
    belonging to that Plaid account (Plaid returns all transactions
    for an Item, which may span multiple accounts).
    Returns the count of newly created transactions.
    """
    created_count = 0
    now = datetime.now(UTC)

    for t in plaid_txns:
        plaid_txn_id = t.get("transaction_id")
        if not plaid_txn_id:
            continue

        # Filter: only store transactions for this specific Plaid account
        if plaid_account_id and t.get("account_id") != plaid_account_id:
            continue

        # Parse the date — Plaid returns "YYYY-MM-DD" or a full datetime string
        date_str = t.get("date") or t.get("authorized_date") or ""
        try:
            if isinstance(date_str, str) and len(date_str) == 10:
                txn_date = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=UTC)
            else:
                txn_date = datetime.fromisoformat(str(date_str))
        except (ValueError, TypeError):
            txn_date = now

        txn = Transaction(
            id=uuid.uuid4(),
            account_id=account_id,
            plaid_transaction_id=plaid_txn_id,
            amount=Decimal(str(t.get("amount", 0))),
            date=txn_date,
            merchant_name=t.get("merchant_name") or t.get("name"),
            category=_map_plaid_category(t),
            subcategory=(
                (t.get("personal_finance_category") or {}).get("detailed")
                if isinstance(t.get("personal_finance_category"), dict)
                else None
            ),
            note=t.get("name"),
            is_recurring=bool(t.get("is_recurring")),
            is_pending=bool(t.get("pending", False)),
            created_at=now,
        )
        try:
            await txn_repo.create(txn)
            created_count += 1
        except IntegrityError:
            logger.debug("Skipping duplicate transaction %s", plaid_txn_id)
        except Exception as exc:
            logger.warning("Failed to store transaction %s: %s", plaid_txn_id, exc, exc_info=True)

    return created_count


async def _sync_account_transactions(
    account: Account,
    access_token: str,
    plaid: PlaidService,
    account_repo: AccountRepository,
    txn_repo: TransactionRepository,
) -> dict:
    """Run Plaid transaction sync for an account and store results.

    Uses the provided unencrypted access_token directly.
    Returns a summary dict with counts.
    """
    result = plaid.sync_transactions(
        access_token,
        cursor=account.plaid_cursor,
    )

    added_count = await _store_synced_transactions(
        result["added"], account.id, txn_repo,
        plaid_account_id=account.plaid_account_id,
    )

    # Update cursor and last_synced_at
    now = datetime.now(UTC)
    await account_repo.update(
        account,
        {
            "plaid_cursor": result["next_cursor"],
            "last_synced_at": now,
            "updated_at": now,
        },
    )

    return {
        "added_count": added_count,
        "modified_count": len(result["modified"]),
        "removed_count": len(result["removed"]),
        "has_more": result["has_more"],
    }


@router.post("/link-token", response_model=PlaidLinkResponse)
async def create_link_token(
    user_id: uuid.UUID = Depends(get_current_user),
    plaid: PlaidService = Depends(get_plaid_service),
) -> PlaidLinkResponse:
    """Create a Plaid Link token for the authenticated user."""
    link_token = plaid.create_link_token(user_id)
    return PlaidLinkResponse(link_token=link_token)


@router.post("/hosted-link-token", response_model=HostedLinkTokenResponse)
async def create_hosted_link_token(
    user_id: uuid.UUID = Depends(get_current_user),
    plaid: PlaidService = Depends(get_plaid_service),
) -> HostedLinkTokenResponse:
    """Create a Plaid Hosted Link token for the authenticated user.

    Returns both a link_token (for session correlation) and a hosted_link_url
    that should be opened in ASWebAuthenticationSession on macOS.
    """
    try:
        link_token, hosted_link_url = plaid.create_hosted_link_token(user_id)
    except Exception:
        logger.exception("Failed to create hosted link token for user=%s", user_id)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to create hosted link token from Plaid",
        )
    # Lazy cleanup of expired entries
    now = time.time()
    expired = [k for k, (_, t) in _link_token_owners.items() if now - t > _LINK_TOKEN_TTL]
    for k in expired:
        del _link_token_owners[k]
    _link_token_owners[link_token] = (user_id, now)
    return HostedLinkTokenResponse(
        link_token=link_token,
        hosted_link_url=hosted_link_url,
    )


@router.post("/resolve-session", response_model=ResolveSessionResponse)
async def resolve_session(
    body: ResolveSessionRequest,
    request: Request,
    user_id: uuid.UUID = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    plaid: PlaidService = Depends(get_plaid_service),
) -> ResolveSessionResponse:
    """Resolve a Plaid Hosted Link session.

    After the user completes bank auth in the hosted browser, the client
    calls this endpoint with the stored link_token. The backend checks
    session status via /link/token/get, and if complete, exchanges the
    public_token for an access_token and creates Account records.
    """
    # Verify link token ownership (pop is atomic under GIL, prevents replay)
    owner = _link_token_owners.pop(body.link_token, None)
    if owner is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Link token not found or expired",
        )
    owner_id, created_at = owner
    if time.time() - created_at > _LINK_TOKEN_TTL:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Link token not found or expired",
        )
    if owner_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Link token does not belong to this user",
        )

    try:
        result = plaid.resolve_hosted_session(body.link_token)
    except Exception:
        logger.exception(
            "Failed to resolve hosted session for user=%s, link_token=%s...",
            user_id,
            body.link_token[:30],
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to resolve session from Plaid",
        )

    session_status = result["status"]

    if session_status != "complete":
        return ResolveSessionResponse(status=session_status, accounts=None)

    # Session is complete — store accounts
    ip = request.client.host if request.client else "unknown"
    log_token_exchange(user_id=str(user_id), provider="plaid-hosted", ip=ip)

    access_token = result["access_token"]
    item_id = result["item_id"]
    plaid_accounts = plaid.get_accounts(access_token)

    settings = get_settings()
    encrypted_token = encrypt_value(access_token, settings.plaid_encryption_key)

    repo = AccountRepository(db)
    created_accounts: list[Account] = []
    now = datetime.now(UTC)

    for plaid_acct in plaid_accounts:
        balances = plaid_acct.get("balances", {})
        account = Account(
            id=uuid.uuid4(),
            user_id=user_id,
            plaid_account_id=plaid_acct.get("account_id", ""),
            plaid_access_token=encrypted_token,
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

    logger.info(
        "Hosted session resolved: user=%s, accounts_created=%d",
        user_id,
        len(created_accounts),
    )

    # Auto-sync transactions for each newly created account
    txn_repo = TransactionRepository(db)
    total_synced = 0
    for account in created_accounts:
        try:
            sync_result = await _sync_account_transactions(
                account=account,
                access_token=access_token,
                plaid=plaid,
                account_repo=repo,
                txn_repo=txn_repo,
            )
            total_synced += sync_result["added_count"]
            logger.info(
                "Auto-synced account %s: %d transactions added",
                account.id,
                sync_result["added_count"],
            )
        except Exception:
            logger.exception(
                "Auto-sync failed for account %s (non-fatal)", account.id
            )

    if total_synced > 0:
        logger.info(
            "Auto-sync complete: user=%s, total_transactions=%d",
            user_id,
            total_synced,
        )

    return ResolveSessionResponse(
        status="complete",
        accounts=[AccountResponse.model_validate(a) for a in created_accounts],
    )


@router.post("/exchange-token", response_model=PlaidExchangeResponse)
async def exchange_token(
    body: PlaidExchangeRequest,
    request: Request,
    user_id: uuid.UUID = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    plaid: PlaidService = Depends(get_plaid_service),
) -> PlaidExchangeResponse:
    """Exchange a Plaid public token and create Account records.

    Calls Plaid to exchange the public_token for an access_token,
    fetches account data, and persists Account records.
    """
    ip = request.client.host if request.client else "unknown"
    log_token_exchange(user_id=str(user_id), provider="plaid", ip=ip)
    access_token, item_id = plaid.exchange_public_token(body.public_token)
    plaid_accounts = plaid.get_accounts(access_token)

    settings = get_settings()
    encrypted_token = encrypt_value(access_token, settings.plaid_encryption_key)

    repo = AccountRepository(db)
    created_accounts: list[Account] = []
    now = datetime.now(UTC)

    for plaid_acct in plaid_accounts:
        balances = plaid_acct.get("balances", {})
        account = Account(
            id=uuid.uuid4(),
            user_id=user_id,
            plaid_account_id=plaid_acct.get("account_id", ""),
            plaid_access_token=encrypted_token,
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

    settings = get_settings()
    decrypted_token = decrypt_value(
        account.plaid_access_token, settings.plaid_encryption_key
    )

    txn_repo = TransactionRepository(db)
    return await _sync_account_transactions(
        account=account,
        access_token=decrypted_token,
        plaid=plaid,
        account_repo=repo,
        txn_repo=txn_repo,
    )


@router.post(
    "/sandbox/public-token",
    response_model=SandboxPublicTokenResponse,
    status_code=201,
)
async def create_sandbox_public_token(
    body: SandboxPublicTokenRequest = SandboxPublicTokenRequest(),
    user_id: uuid.UUID = Depends(get_current_user),
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
    user_id: uuid.UUID = Depends(get_current_user),
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
    user_id: uuid.UUID = Depends(get_current_user),
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
