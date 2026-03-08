"""Debt SQLAlchemy model."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _utc_now() -> datetime:
    return datetime.now(UTC)


class Debt(Base):
    """Debt obligation linked to a user, optionally tied to an account."""

    __tablename__ = "debts"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    account_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("accounts.id", ondelete="SET NULL")
    )
    debt_name: Mapped[str] = mapped_column(String(255))
    debt_type: Mapped[str] = mapped_column(String(20), nullable=False)
    original_balance: Mapped[Decimal]
    current_balance: Mapped[Decimal]
    interest_rate: Mapped[Decimal]
    minimum_payment: Mapped[Decimal]
    payoff_date: Mapped[datetime | None]
    is_fixed_rate: Mapped[bool]
    created_at: Mapped[datetime] = mapped_column(default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(default=_utc_now, onupdate=_utc_now)

    user: Mapped["User"] = relationship(back_populates="debts")  # noqa: F821
    account: Mapped["Account | None"] = relationship()  # noqa: F821

    @property
    def monthly_interest(self) -> Decimal:
        """Calculate monthly interest charge."""
        return self.current_balance * self.interest_rate / 12

    @property
    def payoff_progress(self) -> Decimal:
        """Calculate payoff progress as a fraction (0..1)."""
        if self.original_balance == 0:
            return Decimal(1)
        return 1 - self.current_balance / self.original_balance
