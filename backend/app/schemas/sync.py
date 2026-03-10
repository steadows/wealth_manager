"""Sync Pydantic schemas for delta sync between client and server."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel

from app.schemas.account import AccountCreate, AccountResponse
from app.schemas.debt import DebtCreate, DebtResponse
from app.schemas.goal import GoalCreate, GoalResponse
from app.schemas.snapshot import SnapshotResponse
from app.schemas.transaction import TransactionResponse


class SyncResponse(BaseModel):
    """Response containing all data modified since the requested timestamp."""

    accounts: list[AccountResponse] = []
    transactions: list[TransactionResponse] = []
    goals: list[GoalResponse] = []
    debts: list[DebtResponse] = []
    snapshots: list[SnapshotResponse] = []
    synced_at: datetime


class ClientChanges(BaseModel):
    """Payload of changes pushed from the client device."""

    accounts: list[AccountCreate] = []
    goals: list[GoalCreate] = []
    debts: list[DebtCreate] = []


class SyncResult(BaseModel):
    """Result of applying client changes on the server."""

    applied_accounts: int = 0
    applied_goals: int = 0
    applied_debts: int = 0
    synced_at: datetime
