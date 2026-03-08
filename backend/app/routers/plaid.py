"""Plaid integration endpoints (Sprint 3 stub)."""

from fastapi import APIRouter

router = APIRouter(prefix="/plaid", tags=["plaid"])


@router.get("/")
async def plaid_status() -> dict:
    """Plaid endpoint placeholder."""
    return {"status": "not_implemented"}
