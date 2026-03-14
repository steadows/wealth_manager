"""Sync endpoints for delta sync between client and server."""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.schemas.common import APIResponse
from app.schemas.sync import ClientChanges, SyncResponse, SyncResult
from app.services.sync_service import SyncService

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/", response_model=APIResponse[SyncResponse])
async def get_sync(
    since: datetime | None = Query(default=None, description="ISO8601 timestamp for delta sync"),
    limit: int = Query(default=500, ge=1, le=5000, description="Max records per entity type"),
    offset: int = Query(default=0, ge=0, description="Offset for pagination"),
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[SyncResponse]:
    """Return all data modified since the given timestamp.

    If `since` is omitted, returns all user data (initial sync).
    The response includes a `synced_at` timestamp for the client
    to use in the next call.
    """
    service = SyncService(db)
    payload = await service.get_changes_since(user_id, since=since, limit=limit, offset=offset)
    return APIResponse(data=payload)


@router.post("/", response_model=APIResponse[SyncResult])
async def post_sync(
    changes: ClientChanges,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[SyncResult]:
    """Accept and apply client changes (accounts, goals, debts).

    Returns counts of applied records and a synced_at timestamp.
    """
    service = SyncService(db)
    result = await service.apply_client_changes(user_id, changes)
    return APIResponse(data=result)
