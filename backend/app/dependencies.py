"""FastAPI dependency injection providers."""

import uuid
from collections.abc import AsyncGenerator

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Yield an async database session, rolling back on error."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_current_user() -> uuid.UUID:
    """Return the current authenticated user ID.

    Sprint 3 stub: raises 501. Will be replaced with JWT validation in Sprint 4.
    Override this dependency in tests with a fixture user.
    """
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Authentication not yet implemented",
    )
