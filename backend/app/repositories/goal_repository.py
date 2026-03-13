"""Goal repository — data access layer for FinancialGoal."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import FinancialGoal
from app.repositories.base import BaseRepository


class GoalRepository(BaseRepository[FinancialGoal]):
    """Repository for FinancialGoal CRUD operations."""

    def __init__(self, session: AsyncSession) -> None:
        super().__init__(FinancialGoal, session)

    async def get_by_user_id(
        self, user_id: uuid.UUID, *, offset: int = 0, limit: int = 100
    ) -> list[FinancialGoal]:
        """Fetch all goals belonging to a specific user."""
        stmt = (
            select(FinancialGoal)
            .where(FinancialGoal.user_id == user_id)
            .offset(offset)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())
