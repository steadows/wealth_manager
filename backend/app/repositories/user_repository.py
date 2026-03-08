"""User-specific repository operations."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    """Repository for User model with Apple ID lookup."""

    def __init__(self, session: AsyncSession) -> None:
        super().__init__(User, session)

    async def get_by_apple_id(self, apple_id: str) -> User | None:
        """Find a user by their Apple Sign-In identifier."""
        stmt = select(User).where(User.apple_id == apple_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_or_create_by_apple_id(
        self, apple_id: str, email: str | None = None
    ) -> tuple[User, bool]:
        """Find existing user or create a new one.

        Returns a tuple of (user, created) where created is True if new.
        """
        existing = await self.get_by_apple_id(apple_id)
        if existing is not None:
            return existing, False

        new_user = User(id=uuid.uuid4(), apple_id=apple_id, email=email)
        created = await self.create(new_user)
        return created, True
