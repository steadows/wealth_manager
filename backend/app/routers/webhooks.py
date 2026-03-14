"""Webhook endpoints — Plaid webhook handler with signature verification."""

from __future__ import annotations

import json
import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.dependencies import get_db
from app.repositories.account_repository import AccountRepository
from app.services.plaid_service import PlaidService, get_plaid_service
from app.utils.encryption import decrypt_value

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


async def _verify_plaid_signature(
    request: Request,
    raw_body: bytes,
    plaid: PlaidService,
) -> JSONResponse | None:
    """Verify Plaid webhook signature. Returns error response or None on success.

    In sandbox mode, missing verification headers produce a warning but are
    allowed through for local development. In production, verification is
    always enforced.

    Args:
        request: The incoming HTTP request.
        raw_body: The raw request body bytes.
        plaid: The PlaidService instance.

    Returns:
        A JSONResponse with 401 status if verification fails, or None if valid.
    """
    settings = get_settings()
    verification_header = request.headers.get("Plaid-Verification")

    if not verification_header:
        if settings.plaid_env == "sandbox":
            logger.warning(
                "Plaid webhook received without Plaid-Verification header "
                "(allowed in sandbox mode)"
            )
            return None
        logger.error("Plaid webhook rejected: missing Plaid-Verification header")
        return JSONResponse(
            status_code=401,
            content={"detail": "Missing Plaid-Verification header"},
        )

    try:
        plaid.verify_webhook_body(raw_body, verification_header)
    except ValueError as exc:
        logger.error("Plaid webhook signature verification failed: %s", exc)
        return JSONResponse(
            status_code=401,
            content={"detail": "Webhook signature verification failed"},
        )

    return None


@router.post("/plaid", response_model=None)
async def plaid_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    plaid: PlaidService = Depends(get_plaid_service),
) -> dict | JSONResponse:
    """Receive and handle Plaid webhook events.

    Verifies the Plaid-Verification JWT signature before processing.
    Currently handles TRANSACTIONS webhook_type with
    SYNC_UPDATES_AVAILABLE webhook_code by triggering a sync.
    """
    raw_body = await request.body()

    # Verify webhook signature
    error_response = await _verify_plaid_signature(request, raw_body, plaid)
    if error_response is not None:
        return error_response

    body: dict = json.loads(raw_body)
    webhook_type = body.get("webhook_type", "")
    webhook_code = body.get("webhook_code", "")
    item_id = body.get("item_id", "")

    logger.info(
        "Plaid webhook received: type=%s code=%s item_id=%s",
        webhook_type,
        webhook_code,
        item_id,
    )

    if webhook_type == "TRANSACTIONS" and webhook_code == "SYNC_UPDATES_AVAILABLE":
        repo = AccountRepository(db)
        accounts = await repo.get_by_plaid_item_id(item_id)

        settings = get_settings()
        synced_count = 0
        for account in accounts:
            if account.plaid_access_token:
                decrypted_token = decrypt_value(
                    account.plaid_access_token, settings.plaid_encryption_key
                )
                result = plaid.sync_transactions(
                    decrypted_token,
                    cursor=account.plaid_cursor,
                )
                await repo.update(
                    account,
                    {
                        "plaid_cursor": result["next_cursor"],
                        "last_synced_at": datetime.now(UTC),
                        "updated_at": datetime.now(UTC),
                    },
                )
                synced_count += 1

        return {"status": "synced", "accounts_synced": synced_count}

    return {"status": "ignored", "webhook_type": webhook_type, "webhook_code": webhook_code}
