"""InvestmentHolding SQLAlchemy model."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InvestmentHolding(Base):
    """Investment position within an account."""

    __tablename__ = "investment_holdings"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"))
    security_name: Mapped[str] = mapped_column(String(255))
    ticker_symbol: Mapped[str | None] = mapped_column(String(20))
    quantity: Mapped[Decimal]
    cost_basis: Mapped[Decimal | None]
    current_price: Mapped[Decimal]
    holding_type: Mapped[str] = mapped_column(String(20), nullable=False)
    asset_class: Mapped[str] = mapped_column(String(20), nullable=False)
    purchase_date: Mapped[datetime | None]
    last_price_update: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))

    account: Mapped["Account"] = relationship(back_populates="holdings")  # noqa: F821

    @property
    def current_value(self) -> Decimal:
        """Calculate current market value."""
        return self.quantity * self.current_price

    @property
    def gain_loss(self) -> Decimal | None:
        """Calculate total gain/loss from cost basis."""
        if self.cost_basis is None:
            return None
        return self.current_value - (self.cost_basis * self.quantity)

    @property
    def gain_loss_percent(self) -> Decimal | None:
        """Calculate gain/loss as a percentage."""
        if self.cost_basis is None or self.cost_basis == 0:
            return None
        total_cost = self.cost_basis * self.quantity
        if total_cost == 0:
            return None
        return (self.current_value - total_cost) / total_cost
