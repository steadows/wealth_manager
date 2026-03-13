"""FinancialGoal SQLAlchemy model."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _utc_now() -> datetime:
    return datetime.now(UTC)


class FinancialGoal(Base):
    """Financial goal belonging to a user."""

    __tablename__ = "financial_goals"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    goal_name: Mapped[str] = mapped_column(String(255))
    goal_type: Mapped[str] = mapped_column(String(20), nullable=False)
    target_amount: Mapped[Decimal]
    current_amount: Mapped[Decimal] = mapped_column(default=Decimal(0))
    target_date: Mapped[datetime | None]
    monthly_contribution: Mapped[Decimal | None]
    priority: Mapped[str] = mapped_column(String(20))
    is_active: Mapped[bool] = mapped_column(default=True)
    notes: Mapped[str | None] = mapped_column(String(1000))
    created_at: Mapped[datetime] = mapped_column(default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(default=_utc_now, onupdate=_utc_now)

    user: Mapped["User"] = relationship(back_populates="goals")  # noqa: F821

    @property
    def progress_percent(self) -> Decimal:
        """Calculate progress toward the goal as a fraction."""
        if self.target_amount == 0:
            return Decimal(0)
        return self.current_amount / self.target_amount

    @property
    def remaining_amount(self) -> Decimal:
        """Calculate the amount still needed."""
        return self.target_amount - self.current_amount
