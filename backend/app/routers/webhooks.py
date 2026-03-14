"""Webhook endpoints — Plaid webhook handler."""

from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.repositories.account_repository import AccountRepository
from app.services.plaid_service import PlaidService, get_plaid_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/plaid")
async def plaid_webhook(
    body: dict,
    db: AsyncSession = Depends(get_db),
    plaid: PlaidService = Depends(get_plaid_service),
) -> dict:
    """Receive and handle Plaid webhook events.

    Currently handles TRANSACTIONS webhook_type with
    SYNC_UPDATES_AVAILABLE webhook_code by triggering a sync.
    """
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

        synced_count = 0
        for account in accounts:
            if account.plaid_access_token:
                result = plaid.sync_transactions(
                    account.plaid_access_token,
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
