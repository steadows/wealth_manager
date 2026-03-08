"""Pydantic schemas for request/response validation."""

from app.schemas.account import AccountCreate, AccountResponse, AccountUpdate
from app.schemas.auth import LoginRequest, LoginResponse, TokenResponse
from app.schemas.common import APIResponse, ErrorResponse, PaginatedResponse
from app.schemas.debt import DebtCreate, DebtResponse, DebtUpdate
from app.schemas.goal import GoalCreate, GoalResponse, GoalUpdate
from app.schemas.holding import HoldingCreate, HoldingResponse, HoldingUpdate
from app.schemas.plaid import PlaidLinkRequest, PlaidLinkResponse
from app.schemas.snapshot import SnapshotCreate, SnapshotResponse
from app.schemas.sync import SyncRequest, SyncResponse
from app.schemas.transaction import TransactionCreate, TransactionResponse, TransactionUpdate
from app.schemas.user import UserProfileResponse, UserProfileUpdate, UserResponse

__all__ = [
    "APIResponse",
    "AccountCreate",
    "AccountResponse",
    "AccountUpdate",
    "DebtCreate",
    "DebtResponse",
    "DebtUpdate",
    "ErrorResponse",
    "GoalCreate",
    "GoalResponse",
    "GoalUpdate",
    "HoldingCreate",
    "HoldingResponse",
    "HoldingUpdate",
    "LoginRequest",
    "LoginResponse",
    "PaginatedResponse",
    "PlaidLinkRequest",
    "PlaidLinkResponse",
    "SnapshotCreate",
    "SnapshotResponse",
    "SyncRequest",
    "SyncResponse",
    "TokenResponse",
    "TransactionCreate",
    "TransactionResponse",
    "TransactionUpdate",
    "UserProfileResponse",
    "UserProfileUpdate",
    "UserResponse",
]
