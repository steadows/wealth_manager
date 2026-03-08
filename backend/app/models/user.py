"""User and UserProfile SQLAlchemy models."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.enums import FilingStatus, RiskTolerance


def _utc_now() -> datetime:
    return datetime.now(UTC)


class User(Base):
    """Core user account, linked to Apple Sign-In."""

    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    apple_id: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(default=_utc_now, onupdate=_utc_now)

    profile: Mapped["UserProfile | None"] = relationship(
        back_populates="user", cascade="all, delete-orphan", uselist=False
    )
    accounts: Mapped[list["Account"]] = relationship(  # noqa: F821
        back_populates="user", cascade="all, delete-orphan"
    )
    goals: Mapped[list["FinancialGoal"]] = relationship(  # noqa: F821
        back_populates="user", cascade="all, delete-orphan"
    )
    debts: Mapped[list["Debt"]] = relationship(  # noqa: F821
        back_populates="user", cascade="all, delete-orphan"
    )
    snapshots: Mapped[list["NetWorthSnapshot"]] = relationship(  # noqa: F821
        back_populates="user", cascade="all, delete-orphan"
    )


class UserProfile(Base):
    """Extended profile information for a user."""

    __tablename__ = "user_profiles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True
    )
    date_of_birth: Mapped[datetime | None]
    annual_income: Mapped[Decimal | None]
    monthly_expenses: Mapped[Decimal | None]
    filing_status: Mapped[str] = mapped_column(
        String(30), default=FilingStatus.SINGLE, nullable=False
    )
    state_of_residence: Mapped[str | None] = mapped_column(String(2))
    retirement_age: Mapped[int] = mapped_column(default=65)
    risk_tolerance: Mapped[str] = mapped_column(
        String(20), default=RiskTolerance.MODERATE, nullable=False
    )
    dependents: Mapped[int] = mapped_column(default=0)
    has_spouse: Mapped[bool] = mapped_column(default=False)
    spouse_income: Mapped[Decimal | None]
    created_at: Mapped[datetime] = mapped_column(default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(default=_utc_now, onupdate=_utc_now)

    user: Mapped["User"] = relationship(back_populates="profile")

    __table_args__ = (Index("ix_user_profiles_user_id", "user_id"),)
