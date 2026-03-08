"""SQLAlchemy models — import all models so Base.metadata discovers them."""

from app.database import Base
from app.models.account import Account
from app.models.debt import Debt
from app.models.goal import FinancialGoal
from app.models.holding import InvestmentHolding
from app.models.snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User, UserProfile

__all__ = [
    "Account",
    "Base",
    "Debt",
    "FinancialGoal",
    "InvestmentHolding",
    "NetWorthSnapshot",
    "Transaction",
    "User",
    "UserProfile",
]
