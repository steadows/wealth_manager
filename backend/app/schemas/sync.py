"""Sync Pydantic schemas (Sprint 3 stubs)."""

from pydantic import BaseModel


class SyncRequest(BaseModel):
    """Request to sync data from client to server."""

    last_sync_timestamp: str | None = None


class SyncResponse(BaseModel):
    """Response containing sync delta."""

    status: str = "not_implemented"
    synced_at: str | None = None
