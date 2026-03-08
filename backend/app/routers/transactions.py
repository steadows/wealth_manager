"""Transaction endpoints (Sprint 3 stub)."""

from fastapi import APIRouter

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("/")
async def transactions_status() -> dict:
    """Transactions endpoint placeholder."""
    return {"status": "not_implemented"}
