"""Generic base repository with common CRUD operations."""

import uuid
from typing import Generic, TypeVar

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import Base

ModelType = TypeVar("ModelType", bound=Base)


class BaseRepository(Generic[ModelType]):
    """Generic repository providing standard CRUD operations."""

    def __init__(self, model: type[ModelType], session: AsyncSession) -> None:
        self._model = model
        self._session = session

    async def get_by_id(self, record_id: uuid.UUID) -> ModelType | None:
        """Fetch a single record by its primary key."""
        return await self._session.get(self._model, record_id)

    async def get_all(self, *, offset: int = 0, limit: int = 100) -> list[ModelType]:
        """Fetch all records with optional pagination."""
        stmt = select(self._model).offset(offset).limit(limit)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def create(self, record: ModelType) -> ModelType:
        """Persist a new record and return it."""
        self._session.add(record)
        await self._session.flush()
        await self._session.refresh(record)
        return record

    async def update(self, record: ModelType, data: dict) -> ModelType:
        """Update a record with the provided field values.

        Returns a new reference after refresh (original should not be reused).
        """
        for key, value in data.items():
            if value is not None:
                setattr(record, key, value)
        await self._session.flush()
        await self._session.refresh(record)
        return record

    async def delete(self, record: ModelType) -> None:
        """Remove a record from the database."""
        await self._session.delete(record)
        await self._session.flush()
