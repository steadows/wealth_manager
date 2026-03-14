"""Health check endpoints."""

import logging

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db

logger = logging.getLogger(__name__)

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
    except Exception:
        logger.exception("Database health check failed")
        return {"status": "unhealthy", "database": "disconnected"}


@router.get("/health/redis")
async def health_redis() -> dict:
    """Redis connectivity check (Sprint 3 stub)."""
    return {"status": "healthy", "redis": "not_configured"}
