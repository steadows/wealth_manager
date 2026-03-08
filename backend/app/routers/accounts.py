"""Account CRUD endpoints."""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.schemas.account import AccountCreate, AccountResponse, AccountUpdate
from app.schemas.common import APIResponse
from app.services.account_service import AccountService

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("/", response_model=APIResponse[list[AccountResponse]])
async def list_accounts(
    offset: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[list[AccountResponse]]:
    """List all accounts for the current user."""
    service = AccountService(db)
    accounts = await service.list_accounts(user_id, offset=offset, limit=limit)
    return APIResponse(data=[AccountResponse.model_validate(a) for a in accounts])


@router.get("/{account_id}", response_model=APIResponse[AccountResponse])
async def get_account(
    account_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[AccountResponse]:
    """Get a single account by ID."""
    service = AccountService(db)
    account = await service.get_account(account_id, user_id)
    return APIResponse(data=AccountResponse.model_validate(account))


@router.post("/", response_model=APIResponse[AccountResponse], status_code=201)
async def create_account(
    data: AccountCreate,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[AccountResponse]:
    """Create a new account."""
    service = AccountService(db)
    account = await service.create_account(user_id, data)
    return APIResponse(data=AccountResponse.model_validate(account))


@router.patch("/{account_id}", response_model=APIResponse[AccountResponse])
async def update_account(
    account_id: uuid.UUID,
    data: AccountUpdate,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> APIResponse[AccountResponse]:
    """Update an existing account."""
    service = AccountService(db)
    account = await service.update_account(account_id, user_id, data)
    return APIResponse(data=AccountResponse.model_validate(account))


@router.delete("/{account_id}", status_code=204)
async def delete_account(
    account_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user),
) -> None:
    """Delete an account."""
    service = AccountService(db)
    await service.delete_account(account_id, user_id)
