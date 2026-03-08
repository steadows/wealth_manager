"""Account-specific repository operations."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.repositories.base import BaseRepository


class AccountRepository(BaseRepository[Account]):
    """Repository for Account model with user-scoped queries."""

    def __init__(self, session: AsyncSession) -> None:
        super().__init__(Account, session)

    async def get_by_user_id(
        self, user_id: uuid.UUID, *, offset: int = 0, limit: int = 100
    ) -> list[Account]:
        """Fetch all accounts belonging to a specific user."""
        stmt = (
            select(Account)
            .where(Account.user_id == user_id)
            .offset(offset)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_by_plaid_item_id(self, plaid_item_id: str) -> list[Account]:
        """Fetch all accounts linked to a specific Plaid item."""
        stmt = select(Account).where(Account.plaid_item_id == plaid_item_id)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())
