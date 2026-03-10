"""Delta sync service for client-server data synchronization."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.debt import Debt
from app.models.goal import FinancialGoal
from app.models.snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.schemas.account import AccountResponse
from app.schemas.debt import DebtResponse
from app.schemas.goal import GoalResponse
from app.schemas.snapshot import SnapshotResponse
from app.schemas.sync import ClientChanges, SyncResponse, SyncResult
from app.schemas.transaction import TransactionResponse


class SyncService:
    """Service for delta sync operations between backend and iOS/macOS app."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_changes_since(
        self,
        user_id: uuid.UUID,
        since: datetime | None,
    ) -> SyncResponse:
        """Query all entities modified after `since` for the given user.

        If `since` is None, returns all data (initial sync).
        All queries filter by user_id for data isolation.
        """
        accounts = await self._get_accounts_since(user_id, since)
        transactions = await self._get_transactions_since(user_id, since, accounts)
        goals = await self._get_goals_since(user_id, since)
        debts = await self._get_debts_since(user_id, since)
        snapshots = await self._get_snapshots_since(user_id, since)

        return SyncResponse(
            accounts=[AccountResponse.model_validate(a) for a in accounts],
            transactions=[TransactionResponse.model_validate(t) for t in transactions],
            goals=[GoalResponse.model_validate(g) for g in goals],
            debts=[DebtResponse.model_validate(d) for d in debts],
            snapshots=[SnapshotResponse.model_validate(s) for s in snapshots],
            synced_at=datetime.now(UTC),
        )

    async def apply_client_changes(
        self,
        user_id: uuid.UUID,
        changes: ClientChanges,
    ) -> SyncResult:
        """Apply changes pushed from the client device.

        Creates new accounts, goals, and debts from client data.
        All records are assigned to the authenticated user.
        """
        applied_accounts = await self._apply_accounts(user_id, changes)
        applied_goals = await self._apply_goals(user_id, changes)
        applied_debts = await self._apply_debts(user_id, changes)

        return SyncResult(
            applied_accounts=applied_accounts,
            applied_goals=applied_goals,
            applied_debts=applied_debts,
            synced_at=datetime.now(UTC),
        )

    # ── Private query helpers ──────────────────────────────────────────

    async def _get_accounts_since(
        self,
        user_id: uuid.UUID,
        since: datetime | None,
    ) -> list[Account]:
        """Fetch accounts modified after `since`."""
        stmt = select(Account).where(Account.user_id == user_id)
        if since is not None:
            stmt = stmt.where(Account.updated_at > since)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def _get_transactions_since(
        self,
        user_id: uuid.UUID,
        since: datetime | None,
        accounts: list[Account] | None = None,
    ) -> list[Transaction]:
        """Fetch transactions for user's accounts, created after `since`.

        Transactions don't have updated_at, so we filter by created_at.
        We join through Account to enforce user_id filtering.
        """
        stmt = (
            select(Transaction)
            .join(Account, Transaction.account_id == Account.id)
            .where(Account.user_id == user_id)
        )
        if since is not None:
            stmt = stmt.where(Transaction.created_at > since)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def _get_goals_since(
        self,
        user_id: uuid.UUID,
        since: datetime | None,
    ) -> list[FinancialGoal]:
        """Fetch goals modified after `since`."""
        stmt = select(FinancialGoal).where(FinancialGoal.user_id == user_id)
        if since is not None:
            stmt = stmt.where(FinancialGoal.updated_at > since)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def _get_debts_since(
        self,
        user_id: uuid.UUID,
        since: datetime | None,
    ) -> list[Debt]:
        """Fetch debts modified after `since`."""
        stmt = select(Debt).where(Debt.user_id == user_id)
        if since is not None:
            stmt = stmt.where(Debt.updated_at > since)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def _get_snapshots_since(
        self,
        user_id: uuid.UUID,
        since: datetime | None,
    ) -> list[NetWorthSnapshot]:
        """Fetch snapshots created after `since`.

        NetWorthSnapshot uses `date` as its timestamp field.
        """
        stmt = select(NetWorthSnapshot).where(NetWorthSnapshot.user_id == user_id)
        if since is not None:
            stmt = stmt.where(NetWorthSnapshot.date > since)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    # ── Private apply helpers ──────────────────────────────────────────

    async def _apply_accounts(
        self,
        user_id: uuid.UUID,
        changes: ClientChanges,
    ) -> int:
        """Create accounts from client changes."""
        now = datetime.now(UTC)
        for acct_data in changes.accounts:
            account = Account(
                id=uuid.uuid4(),
                user_id=user_id,
                institution_name=acct_data.institution_name,
                account_name=acct_data.account_name,
                account_type=acct_data.account_type,
                current_balance=acct_data.current_balance,
                available_balance=acct_data.available_balance,
                currency=acct_data.currency,
                is_manual=acct_data.is_manual,
                created_at=now,
                updated_at=now,
            )
            self._session.add(account)
        if changes.accounts:
            await self._session.flush()
        return len(changes.accounts)

    async def _apply_goals(
        self,
        user_id: uuid.UUID,
        changes: ClientChanges,
    ) -> int:
        """Create goals from client changes."""
        now = datetime.now(UTC)
        for goal_data in changes.goals:
            goal = FinancialGoal(
                id=uuid.uuid4(),
                user_id=user_id,
                goal_name=goal_data.goal_name,
                goal_type=goal_data.goal_type,
                target_amount=goal_data.target_amount,
                current_amount=goal_data.current_amount,
                target_date=goal_data.target_date,
                monthly_contribution=goal_data.monthly_contribution,
                priority=goal_data.priority,
                is_active=goal_data.is_active,
                notes=goal_data.notes,
                created_at=now,
                updated_at=now,
            )
            self._session.add(goal)
        if changes.goals:
            await self._session.flush()
        return len(changes.goals)

    async def _apply_debts(
        self,
        user_id: uuid.UUID,
        changes: ClientChanges,
    ) -> int:
        """Create debts from client changes."""
        now = datetime.now(UTC)
        for debt_data in changes.debts:
            debt = Debt(
                id=uuid.uuid4(),
                user_id=user_id,
                account_id=debt_data.account_id,
                debt_name=debt_data.debt_name,
                debt_type=debt_data.debt_type,
                original_balance=debt_data.original_balance,
                current_balance=debt_data.current_balance,
                interest_rate=debt_data.interest_rate,
                minimum_payment=debt_data.minimum_payment,
                payoff_date=debt_data.payoff_date,
                is_fixed_rate=debt_data.is_fixed_rate,
                created_at=now,
                updated_at=now,
            )
            self._session.add(debt)
        if changes.debts:
            await self._session.flush()
        return len(changes.debts)
