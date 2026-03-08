"""Account service with ownership validation."""

import uuid
from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.repositories.account_repository import AccountRepository
from app.schemas.account import AccountCreate, AccountUpdate


class AccountService:
    """Service layer for account CRUD with ownership checks."""

    def __init__(self, session: AsyncSession) -> None:
        self._repo = AccountRepository(session)

    async def list_accounts(
        self, user_id: uuid.UUID, *, offset: int = 0, limit: int = 100
    ) -> list[Account]:
        """List all accounts for a user."""
        return await self._repo.get_by_user_id(user_id, offset=offset, limit=limit)

    async def get_account(self, account_id: uuid.UUID, user_id: uuid.UUID) -> Account:
        """Get a single account, verifying ownership."""
        account = await self._repo.get_by_id(account_id)
        if account is None or account.user_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Account not found",
            )
        return account

    async def create_account(self, user_id: uuid.UUID, data: AccountCreate) -> Account:
        """Create a new account for a user."""
        account = Account(
            id=uuid.uuid4(),
            user_id=user_id,
            institution_name=data.institution_name,
            account_name=data.account_name,
            account_type=data.account_type,
            current_balance=data.current_balance,
            available_balance=data.available_balance,
            currency=data.currency,
            is_manual=data.is_manual,
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        return await self._repo.create(account)

    async def update_account(
        self, account_id: uuid.UUID, user_id: uuid.UUID, data: AccountUpdate
    ) -> Account:
        """Update an account, verifying ownership."""
        account = await self.get_account(account_id, user_id)
        update_data = data.model_dump(exclude_none=True)
        update_data["updated_at"] = datetime.now(UTC)
        return await self._repo.update(account, update_data)

    async def delete_account(self, account_id: uuid.UUID, user_id: uuid.UUID) -> None:
        """Delete an account, verifying ownership."""
        account = await self.get_account(account_id, user_id)
        await self._repo.delete(account)
