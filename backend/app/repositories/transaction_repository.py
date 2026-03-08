"""Transaction-specific repository operations."""

import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.transaction import Transaction
from app.repositories.base import BaseRepository


class TransactionRepository(BaseRepository[Transaction]):
    """Repository for Transaction model with date-range queries."""

    def __init__(self, session: AsyncSession) -> None:
        super().__init__(Transaction, session)

    async def get_by_account_id(
        self, account_id: uuid.UUID, *, offset: int = 0, limit: int = 100
    ) -> list[Transaction]:
        """Fetch transactions for a specific account."""
        stmt = (
            select(Transaction)
            .where(Transaction.account_id == account_id)
            .order_by(Transaction.date.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_by_date_range(
        self,
        account_id: uuid.UUID,
        start_date: datetime,
        end_date: datetime,
        *,
        offset: int = 0,
        limit: int = 100,
    ) -> list[Transaction]:
        """Fetch transactions within a date range for an account."""
        stmt = (
            select(Transaction)
            .where(
                Transaction.account_id == account_id,
                Transaction.date >= start_date,
                Transaction.date <= end_date,
            )
            .order_by(Transaction.date.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())
