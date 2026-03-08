"""Authentication endpoints (Sprint 3 stub)."""

from fastapi import APIRouter

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/")
async def auth_status() -> dict:
    """Auth endpoint placeholder."""
    return {"status": "not_implemented"}
