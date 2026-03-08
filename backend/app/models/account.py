"""Account SQLAlchemy model."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.enums import AccountType


def _utc_now() -> datetime:
    return datetime.now(UTC)


class Account(Base):
    """Financial account linked to a user."""

    __tablename__ = "accounts"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    plaid_account_id: Mapped[str | None] = mapped_column(String(255))
    # TODO(security): Encrypt at rest before Sprint 4 launch — use Fernet or pgcrypto
    plaid_access_token: Mapped[str | None] = mapped_column(String(255))
    plaid_item_id: Mapped[str | None] = mapped_column(String(255))
    plaid_cursor: Mapped[str | None] = mapped_column(String(255))
    institution_name: Mapped[str] = mapped_column(String(255))
    account_name: Mapped[str] = mapped_column(String(255))
    account_type: Mapped[str] = mapped_column(String(20), nullable=False)
    current_balance: Mapped[Decimal]
    available_balance: Mapped[Decimal | None]
    currency: Mapped[str] = mapped_column(String(3), default="USD")
    is_manual: Mapped[bool]
    is_hidden: Mapped[bool] = mapped_column(default=False)
    last_synced_at: Mapped[datetime | None]
    created_at: Mapped[datetime] = mapped_column(default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(default=_utc_now, onupdate=_utc_now)

    user: Mapped["User"] = relationship(back_populates="accounts")  # noqa: F821
    transactions: Mapped[list["Transaction"]] = relationship(  # noqa: F821
        back_populates="account", cascade="all, delete-orphan"
    )
    holdings: Mapped[list["InvestmentHolding"]] = relationship(  # noqa: F821
        back_populates="account", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_accounts_user_type", "user_id", "account_type"),
    )

    @property
    def is_asset(self) -> bool:
        """Return True if this account type represents an asset."""
        return self.account_type in {
            AccountType.CHECKING,
            AccountType.SAVINGS,
            AccountType.INVESTMENT,
            AccountType.RETIREMENT,
        }

    @property
    def is_liability(self) -> bool:
        """Return True if this account type represents a liability."""
        return self.account_type in {
            AccountType.CREDIT_CARD,
            AccountType.LOAN,
        }
