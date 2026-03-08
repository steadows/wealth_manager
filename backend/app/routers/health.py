"""Health check endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict:
    """Basic liveness check."""
    return {"status": "healthy"}


@router.get("/health/db")
async def health_db(db: AsyncSession = Depends(get_db)) -> dict:
    """Database connectivity check."""
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as exc:
        return {"status": "unhealthy", "database": "disconnected", "error": str(exc)}


@router.get("/health/redis")
async def health_redis() -> dict:
    """Redis connectivity check (Sprint 3 stub)."""
    return {"status": "healthy", "redis": "not_configured"}
