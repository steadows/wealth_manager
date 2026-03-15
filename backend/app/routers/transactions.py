"""Transaction endpoints — list transactions by account."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.account import Account
from app.models.transaction import Transaction
from app.repositories.transaction_repository import TransactionRepository
from app.schemas.transaction import TransactionListResponse, TransactionResponse

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("/{account_id}", response_model=TransactionListResponse)
async def list_transactions(
    account_id: uuid.UUID,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user_id: uuid.UUID = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TransactionListResponse:
    """Return paginated transactions for an account.

    Verifies the account belongs to the authenticated user before
    returning results ordered by date descending.
    """
    # Verify account exists and belongs to user
    account = await db.get(Account, account_id)
    if account is None or account.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    repo = TransactionRepository(db)
    transactions = await repo.get_by_account_id(
        account_id, offset=offset, limit=limit
    )

    # Get total count for pagination
    count_stmt = (
        select(func.count())
        .select_from(Transaction)
        .where(Transaction.account_id == account_id)
    )
    total = (await db.execute(count_stmt)).scalar_one()

    return TransactionListResponse(
        transactions=[TransactionResponse.model_validate(t) for t in transactions],
        total=total,
        limit=limit,
        offset=offset,
    )
