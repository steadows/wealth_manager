"""Webhook endpoints (Sprint 3 stub)."""

from fastapi import APIRouter

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.get("/")
async def webhooks_status() -> dict:
    """Webhooks endpoint placeholder."""
    return {"status": "not_implemented"}
