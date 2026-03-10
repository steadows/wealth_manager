"""Tests for the sync service (delta sync logic)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.debt import Debt
from app.models.enums import AccountType, DebtType, GoalType
from app.models.goal import FinancialGoal
from app.models.snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.sync import ClientChanges
from app.services.sync_service import SyncService

TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")
OTHER_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000099")


async def _create_test_user(session: AsyncSession, user_id: uuid.UUID) -> User:
    """Insert a test user and return it."""
    user = User(
        id=user_id,
        apple_id=f"apple.{user_id}",
        email=f"{user_id}@test.com",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    session.add(user)
    await session.flush()
    return user


async def _seed_data(
    session: AsyncSession,
    user_id: uuid.UUID,
    *,
    old_time: datetime,
    new_time: datetime,
) -> dict:
    """Seed accounts, transactions, goals, debts, snapshots with varied timestamps."""
    await _create_test_user(session, user_id)

    # Old account (before cutoff)
    old_account = Account(
        id=uuid.uuid4(),
        user_id=user_id,
        institution_name="Old Bank",
        account_name="Old Checking",
        account_type=AccountType.CHECKING,
        current_balance=Decimal("1000.0000"),
        is_manual=True,
        created_at=old_time,
        updated_at=old_time,
    )
    # New account (after cutoff)
    new_account = Account(
        id=uuid.uuid4(),
        user_id=user_id,
        institution_name="New Bank",
        account_name="New Savings",
        account_type=AccountType.SAVINGS,
        current_balance=Decimal("5000.0000"),
        is_manual=True,
        created_at=new_time,
        updated_at=new_time,
    )
    session.add_all([old_account, new_account])
    await session.flush()

    # Transactions — old one linked to old_account, new one to new_account
    old_txn = Transaction(
        id=uuid.uuid4(),
        account_id=old_account.id,
        amount=Decimal("-50.0000"),
        date=old_time,
        category="food",
        created_at=old_time,
    )
    new_txn = Transaction(
        id=uuid.uuid4(),
        account_id=new_account.id,
        amount=Decimal("-100.0000"),
        date=new_time,
        category="shopping",
        created_at=new_time,
    )
    session.add_all([old_txn, new_txn])
    await session.flush()

    # Goals
    old_goal = FinancialGoal(
        id=uuid.uuid4(),
        user_id=user_id,
        goal_name="Old Goal",
        goal_type=GoalType.EMERGENCY_FUND,
        target_amount=Decimal("10000.0000"),
        current_amount=Decimal("2000.0000"),
        priority=1,
        created_at=old_time,
        updated_at=old_time,
    )
    new_goal = FinancialGoal(
        id=uuid.uuid4(),
        user_id=user_id,
        goal_name="New Goal",
        goal_type=GoalType.RETIREMENT,
        target_amount=Decimal("500000.0000"),
        current_amount=Decimal("50000.0000"),
        priority=2,
        created_at=new_time,
        updated_at=new_time,
    )
    session.add_all([old_goal, new_goal])
    await session.flush()

    # Debts
    old_debt = Debt(
        id=uuid.uuid4(),
        user_id=user_id,
        debt_name="Old Loan",
        debt_type=DebtType.AUTO,
        original_balance=Decimal("20000.0000"),
        current_balance=Decimal("15000.0000"),
        interest_rate=Decimal("0.0500"),
        minimum_payment=Decimal("400.0000"),
        is_fixed_rate=True,
        created_at=old_time,
        updated_at=old_time,
    )
    new_debt = Debt(
        id=uuid.uuid4(),
        user_id=user_id,
        debt_name="New Card",
        debt_type=DebtType.CREDIT_CARD,
        original_balance=Decimal("5000.0000"),
        current_balance=Decimal("3000.0000"),
        interest_rate=Decimal("0.1900"),
        minimum_payment=Decimal("100.0000"),
        is_fixed_rate=False,
        created_at=new_time,
        updated_at=new_time,
    )
    session.add_all([old_debt, new_debt])
    await session.flush()

    # Snapshots (use date field, no updated_at)
    old_snap = NetWorthSnapshot(
        id=uuid.uuid4(),
        user_id=user_id,
        date=old_time,
        total_assets=Decimal("50000.0000"),
        total_liabilities=Decimal("20000.0000"),
    )
    new_snap = NetWorthSnapshot(
        id=uuid.uuid4(),
        user_id=user_id,
        date=new_time,
        total_assets=Decimal("60000.0000"),
        total_liabilities=Decimal("18000.0000"),
    )
    session.add_all([old_snap, new_snap])
    await session.flush()

    return {
        "old_account": old_account,
        "new_account": new_account,
        "old_txn": old_txn,
        "new_txn": new_txn,
        "old_goal": old_goal,
        "new_goal": new_goal,
        "old_debt": old_debt,
        "new_debt": new_debt,
        "old_snap": old_snap,
        "new_snap": new_snap,
    }


@pytest.mark.asyncio
async def test_initial_sync_returns_everything(session: AsyncSession) -> None:
    """When since=None, get_changes_since returns all user data."""
    old_time = datetime(2025, 1, 1, tzinfo=UTC)
    new_time = datetime(2025, 6, 1, tzinfo=UTC)
    await _seed_data(session, TEST_USER_ID, old_time=old_time, new_time=new_time)

    service = SyncService(session)
    payload = await service.get_changes_since(TEST_USER_ID, since=None)

    assert len(payload.accounts) == 2
    assert len(payload.transactions) == 2
    assert len(payload.goals) == 2
    assert len(payload.debts) == 2
    assert len(payload.snapshots) == 2
    assert payload.synced_at is not None


@pytest.mark.asyncio
async def test_delta_sync_returns_only_new_data(session: AsyncSession) -> None:
    """When since is set, only records modified after that timestamp are returned."""
    old_time = datetime(2025, 1, 1, tzinfo=UTC)
    new_time = datetime(2025, 6, 1, tzinfo=UTC)
    cutoff = datetime(2025, 3, 1, tzinfo=UTC)
    await _seed_data(session, TEST_USER_ID, old_time=old_time, new_time=new_time)

    service = SyncService(session)
    payload = await service.get_changes_since(TEST_USER_ID, since=cutoff)

    # Only the "new" records should appear
    assert len(payload.accounts) == 1
    assert payload.accounts[0].account_name == "New Savings"

    assert len(payload.transactions) == 1
    assert payload.transactions[0].category == "shopping"

    assert len(payload.goals) == 1
    assert payload.goals[0].goal_name == "New Goal"

    assert len(payload.debts) == 1
    assert payload.debts[0].debt_name == "New Card"

    assert len(payload.snapshots) == 1
    assert payload.snapshots[0].total_assets == Decimal("60000.0000")


@pytest.mark.asyncio
async def test_delta_sync_empty_when_no_changes(session: AsyncSession) -> None:
    """When since is after all changes, returns empty collections."""
    old_time = datetime(2025, 1, 1, tzinfo=UTC)
    new_time = datetime(2025, 6, 1, tzinfo=UTC)
    future_cutoff = datetime(2026, 1, 1, tzinfo=UTC)
    await _seed_data(session, TEST_USER_ID, old_time=old_time, new_time=new_time)

    service = SyncService(session)
    payload = await service.get_changes_since(TEST_USER_ID, since=future_cutoff)

    assert len(payload.accounts) == 0
    assert len(payload.transactions) == 0
    assert len(payload.goals) == 0
    assert len(payload.debts) == 0
    assert len(payload.snapshots) == 0


@pytest.mark.asyncio
async def test_sync_filters_by_user_id(session: AsyncSession) -> None:
    """Sync only returns data belonging to the requesting user."""
    old_time = datetime(2025, 1, 1, tzinfo=UTC)
    new_time = datetime(2025, 6, 1, tzinfo=UTC)
    await _seed_data(session, TEST_USER_ID, old_time=old_time, new_time=new_time)

    # Create second user with data
    await _create_test_user(session, OTHER_USER_ID)
    other_account = Account(
        id=uuid.uuid4(),
        user_id=OTHER_USER_ID,
        institution_name="Other Bank",
        account_name="Other Checking",
        account_type=AccountType.CHECKING,
        current_balance=Decimal("9999.0000"),
        is_manual=True,
        created_at=new_time,
        updated_at=new_time,
    )
    session.add(other_account)
    await session.flush()

    service = SyncService(session)
    payload = await service.get_changes_since(TEST_USER_ID, since=None)

    # Should only see TEST_USER_ID data
    assert len(payload.accounts) == 2
    account_names = {a.account_name for a in payload.accounts}
    assert "Other Checking" not in account_names


@pytest.mark.asyncio
async def test_apply_client_changes_creates_records(session: AsyncSession) -> None:
    """apply_client_changes creates accounts, goals, and debts from client data."""
    await _create_test_user(session, TEST_USER_ID)

    changes = ClientChanges(
        accounts=[
            {
                "institution_name": "Client Bank",
                "account_name": "Client Checking",
                "account_type": AccountType.CHECKING,
                "current_balance": Decimal("2500.0000"),
                "is_manual": True,
            }
        ],
        goals=[
            {
                "goal_name": "Client Goal",
                "goal_type": GoalType.CUSTOM,
                "target_amount": Decimal("10000.0000"),
                "priority": 1,
            }
        ],
        debts=[
            {
                "debt_name": "Client Debt",
                "debt_type": DebtType.PERSONAL,
                "original_balance": Decimal("5000.0000"),
                "current_balance": Decimal("4000.0000"),
                "interest_rate": Decimal("0.0800"),
                "minimum_payment": Decimal("150.0000"),
                "is_fixed_rate": True,
            }
        ],
    )

    service = SyncService(session)
    result = await service.apply_client_changes(TEST_USER_ID, changes)

    assert result.applied_accounts == 1
    assert result.applied_goals == 1
    assert result.applied_debts == 1
    assert result.synced_at is not None


@pytest.mark.asyncio
async def test_apply_empty_client_changes(session: AsyncSession) -> None:
    """apply_client_changes with no data returns zero counts."""
    await _create_test_user(session, TEST_USER_ID)

    changes = ClientChanges()
    service = SyncService(session)
    result = await service.apply_client_changes(TEST_USER_ID, changes)

    assert result.applied_accounts == 0
    assert result.applied_goals == 0
    assert result.applied_debts == 0


@pytest.mark.asyncio
async def test_apply_multiple_records_per_type(session: AsyncSession) -> None:
    """apply_client_changes correctly counts multiple records per entity type."""
    await _create_test_user(session, TEST_USER_ID)

    changes = ClientChanges(
        accounts=[
            {
                "institution_name": "Bank A",
                "account_name": "Checking A",
                "account_type": AccountType.CHECKING,
                "current_balance": Decimal("1000.0000"),
                "is_manual": True,
            },
            {
                "institution_name": "Bank B",
                "account_name": "Savings B",
                "account_type": AccountType.SAVINGS,
                "current_balance": Decimal("5000.0000"),
                "is_manual": True,
            },
        ],
        goals=[
            {
                "goal_name": "Goal 1",
                "goal_type": GoalType.EMERGENCY_FUND,
                "target_amount": Decimal("10000.0000"),
                "priority": 1,
            },
            {
                "goal_name": "Goal 2",
                "goal_type": GoalType.TRAVEL,
                "target_amount": Decimal("3000.0000"),
                "priority": 2,
            },
        ],
        debts=[
            {
                "debt_name": "Debt 1",
                "debt_type": DebtType.PERSONAL,
                "original_balance": Decimal("5000.0000"),
                "current_balance": Decimal("4000.0000"),
                "interest_rate": Decimal("0.0800"),
                "minimum_payment": Decimal("150.0000"),
                "is_fixed_rate": True,
            },
        ],
    )

    service = SyncService(session)
    result = await service.apply_client_changes(TEST_USER_ID, changes)

    assert result.applied_accounts == 2
    assert result.applied_goals == 2
    assert result.applied_debts == 1


@pytest.mark.asyncio
async def test_apply_changes_assigns_user_id(session: AsyncSession) -> None:
    """Applied records are correctly assigned to the requesting user."""
    await _create_test_user(session, TEST_USER_ID)

    changes = ClientChanges(
        accounts=[
            {
                "institution_name": "User Bank",
                "account_name": "User Checking",
                "account_type": AccountType.CHECKING,
                "current_balance": Decimal("2000.0000"),
                "is_manual": True,
            },
        ],
    )

    service = SyncService(session)
    await service.apply_client_changes(TEST_USER_ID, changes)

    # Verify the created account belongs to the user
    payload = await service.get_changes_since(TEST_USER_ID, since=None)
    assert len(payload.accounts) == 1
    assert payload.accounts[0].account_name == "User Checking"

    # Other user should see nothing
    await _create_test_user(session, OTHER_USER_ID)
    other_payload = await service.get_changes_since(OTHER_USER_ID, since=None)
    assert len(other_payload.accounts) == 0


@pytest.mark.asyncio
async def test_sync_returns_synced_at_timestamp(session: AsyncSession) -> None:
    """Both get_changes_since and apply_client_changes return a synced_at timestamp."""
    await _create_test_user(session, TEST_USER_ID)

    service = SyncService(session)

    before = datetime.now(UTC)
    get_result = await service.get_changes_since(TEST_USER_ID, since=None)
    assert get_result.synced_at >= before

    changes = ClientChanges()
    apply_result = await service.apply_client_changes(TEST_USER_ID, changes)
    assert apply_result.synced_at >= before


@pytest.mark.asyncio
async def test_delta_sync_boundary_exact_timestamp(session: AsyncSession) -> None:
    """Delta sync with since=exact_time of a record should NOT include it (strictly greater)."""
    exact_time = datetime(2025, 6, 1, tzinfo=UTC)
    old_time = datetime(2025, 1, 1, tzinfo=UTC)
    await _seed_data(session, TEST_USER_ID, old_time=old_time, new_time=exact_time)

    service = SyncService(session)
    # Since equals the new_time exactly — strictly > should exclude it
    payload = await service.get_changes_since(TEST_USER_ID, since=exact_time)

    assert len(payload.accounts) == 0
    assert len(payload.transactions) == 0
    assert len(payload.goals) == 0
    assert len(payload.debts) == 0
    assert len(payload.snapshots) == 0
