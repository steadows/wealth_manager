"""NetWorthSnapshot SQLAlchemy model."""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class NetWorthSnapshot(Base):
    """Point-in-time snapshot of a user's net worth."""

    __tablename__ = "net_worth_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    date: Mapped[datetime]
    total_assets: Mapped[Decimal]
    total_liabilities: Mapped[Decimal]

    user: Mapped["User"] = relationship(back_populates="snapshots")  # noqa: F821

    __table_args__ = (
        Index("ix_net_worth_snapshots_user_date", "user_id", "date"),
    )

    @property
    def net_worth(self) -> Decimal:
        """Calculate net worth from assets minus liabilities."""
        return self.total_assets - self.total_liabilities
