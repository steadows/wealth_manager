"""Model creation and persistence tests."""

import uuid
from datetime import datetime
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.debt import Debt
from app.models.enums import AccountType, AssetClass, DebtType, GoalType, HoldingType
from app.models.goal import FinancialGoal
from app.models.holding import InvestmentHolding
from app.models.snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User, UserProfile


@pytest.mark.asyncio
async def test_create_user(session: AsyncSession) -> None:
    """A User can be persisted and retrieved."""
    user = User(
        id=uuid.uuid4(),
        apple_id="test.apple.id",
        email="test@example.com",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    loaded = await session.get(User, user.id)
    assert loaded is not None
    assert loaded.apple_id == "test.apple.id"
    assert loaded.email == "test@example.com"


@pytest.mark.asyncio
async def test_create_user_profile(session: AsyncSession) -> None:
    """A UserProfile can be linked to a User."""
    user = User(
        id=uuid.uuid4(),
        apple_id="profile.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    profile = UserProfile(
        id=uuid.uuid4(),
        user_id=user.id,
        annual_income=Decimal("120000.0000"),
        retirement_age=67,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(profile)
    await session.flush()

    loaded = await session.get(UserProfile, profile.id)
    assert loaded is not None
    assert loaded.user_id == user.id
    assert loaded.annual_income == Decimal("120000.0000")


@pytest.mark.asyncio
async def test_create_account(session: AsyncSession) -> None:
    """An Account can be persisted with proper fields."""
    user = User(
        id=uuid.uuid4(),
        apple_id="acct.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    account = Account(
        id=uuid.uuid4(),
        user_id=user.id,
        institution_name="Test Bank",
        account_name="Checking",
        account_type=AccountType.CHECKING,
        current_balance=Decimal("5000.5000"),
        is_manual=True,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(account)
    await session.flush()

    loaded = await session.get(Account, account.id)
    assert loaded is not None
    assert loaded.institution_name == "Test Bank"
    assert loaded.current_balance == Decimal("5000.5000")
    assert loaded.is_asset is True
    assert loaded.is_liability is False


@pytest.mark.asyncio
async def test_create_transaction(session: AsyncSession) -> None:
    """A Transaction can be persisted linked to an Account."""
    user = User(
        id=uuid.uuid4(),
        apple_id="txn.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    account = Account(
        id=uuid.uuid4(),
        user_id=user.id,
        institution_name="Test Bank",
        account_name="Savings",
        account_type=AccountType.SAVINGS,
        current_balance=Decimal("10000.0000"),
        is_manual=True,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(account)
    await session.flush()

    txn = Transaction(
        id=uuid.uuid4(),
        account_id=account.id,
        amount=Decimal("-42.5000"),
        date=datetime.now(),
        category="food",
        created_at=datetime.now(),
    )
    session.add(txn)
    await session.flush()

    loaded = await session.get(Transaction, txn.id)
    assert loaded is not None
    assert loaded.amount == Decimal("-42.5000")
    assert loaded.category == "food"


@pytest.mark.asyncio
async def test_create_debt(session: AsyncSession) -> None:
    """A Debt can be persisted with computed properties."""
    user = User(
        id=uuid.uuid4(),
        apple_id="debt.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    debt = Debt(
        id=uuid.uuid4(),
        user_id=user.id,
        debt_name="Car Loan",
        debt_type=DebtType.AUTO,
        original_balance=Decimal("25000.0000"),
        current_balance=Decimal("15000.0000"),
        interest_rate=Decimal("0.0500"),
        minimum_payment=Decimal("450.0000"),
        is_fixed_rate=True,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(debt)
    await session.flush()

    loaded = await session.get(Debt, debt.id)
    assert loaded is not None
    assert loaded.debt_name == "Car Loan"
    assert loaded.payoff_progress == Decimal("0.4")


@pytest.mark.asyncio
async def test_create_holding(session: AsyncSession) -> None:
    """An InvestmentHolding can be persisted."""
    user = User(
        id=uuid.uuid4(),
        apple_id="hold.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    account = Account(
        id=uuid.uuid4(),
        user_id=user.id,
        institution_name="Brokerage",
        account_name="Investment",
        account_type=AccountType.INVESTMENT,
        current_balance=Decimal("50000.0000"),
        is_manual=True,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(account)
    await session.flush()

    holding = InvestmentHolding(
        id=uuid.uuid4(),
        account_id=account.id,
        security_name="Apple Inc.",
        ticker_symbol="AAPL",
        quantity=Decimal("10.0000"),
        cost_basis=Decimal("150.0000"),
        current_price=Decimal("175.0000"),
        holding_type=HoldingType.STOCK,
        asset_class=AssetClass.US_EQUITY,
        last_price_update=datetime.now(),
    )
    session.add(holding)
    await session.flush()

    loaded = await session.get(InvestmentHolding, holding.id)
    assert loaded is not None
    assert loaded.current_value == Decimal("1750.0000")
    assert loaded.gain_loss == Decimal("250.0000")


@pytest.mark.asyncio
async def test_create_goal(session: AsyncSession) -> None:
    """A FinancialGoal can be persisted."""
    user = User(
        id=uuid.uuid4(),
        apple_id="goal.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    goal = FinancialGoal(
        id=uuid.uuid4(),
        user_id=user.id,
        goal_name="Emergency Fund",
        goal_type=GoalType.EMERGENCY_FUND,
        target_amount=Decimal("20000.0000"),
        current_amount=Decimal("5000.0000"),
        priority=1,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(goal)
    await session.flush()

    loaded = await session.get(FinancialGoal, goal.id)
    assert loaded is not None
    assert loaded.progress_percent == Decimal("0.25")
    assert loaded.remaining_amount == Decimal("15000.0000")


@pytest.mark.asyncio
async def test_create_snapshot(session: AsyncSession) -> None:
    """A NetWorthSnapshot can be persisted."""
    user = User(
        id=uuid.uuid4(),
        apple_id="snap.test",
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    session.add(user)
    await session.flush()

    snapshot = NetWorthSnapshot(
        id=uuid.uuid4(),
        user_id=user.id,
        date=datetime.now(),
        total_assets=Decimal("100000.0000"),
        total_liabilities=Decimal("30000.0000"),
    )
    session.add(snapshot)
    await session.flush()

    loaded = await session.get(NetWorthSnapshot, snapshot.id)
    assert loaded is not None
    assert loaded.net_worth == Decimal("70000.0000")
