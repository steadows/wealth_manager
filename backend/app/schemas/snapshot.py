"""NetWorthSnapshot Pydantic schemas."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class SnapshotCreate(BaseModel):
    """Schema for creating a net worth snapshot."""

    date: datetime
    total_assets: Decimal
    total_liabilities: Decimal


class SnapshotResponse(BaseModel):
    """NetWorthSnapshot response schema."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    date: datetime
    total_assets: Decimal
    total_liabilities: Decimal
