"""Async SQLAlchemy database engine and session configuration."""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, TIMESTAMP, Numeric
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""

    type_annotation_map = {
        Decimal: Numeric(precision=19, scale=4),
        datetime: TIMESTAMP(timezone=True),
        date: Date(),
    }


def create_engine(database_url: str | None = None):
    """Create an async SQLAlchemy engine."""
    url = database_url or get_settings().database_url
    kwargs: dict = {"echo": False}
    if "sqlite" not in url:
        kwargs["pool_size"] = 10
    return create_async_engine(url, **kwargs)


engine = create_engine()

async_session_factory = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
