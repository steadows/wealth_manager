"""Transaction SQLAlchemy model."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Transaction(Base):
    """Financial transaction belonging to an account."""

    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"))
    plaid_transaction_id: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    amount: Mapped[Decimal]
    date: Mapped[datetime]
    merchant_name: Mapped[str | None] = mapped_column(String(255))
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    subcategory: Mapped[str | None] = mapped_column(String(100))
    note: Mapped[str | None] = mapped_column(String(500))
    is_recurring: Mapped[bool] = mapped_column(default=False)
    is_pending: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))

    account: Mapped["Account"] = relationship(back_populates="transactions")  # noqa: F821

    __table_args__ = (Index("ix_transactions_account_date", "account_id", "date"),)
