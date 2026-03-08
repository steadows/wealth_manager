"""Sync endpoints (Sprint 3 stub)."""

from fastapi import APIRouter

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/")
async def sync_status() -> dict:
    """Sync endpoint placeholder."""
    return {"status": "not_implemented"}
