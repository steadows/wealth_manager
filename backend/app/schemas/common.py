"""Common/shared Pydantic schemas."""

from decimal import Decimal
from typing import Annotated, Generic, TypeVar

from pydantic import BaseModel, PlainSerializer

# Pydantic v2 serializes Decimal as string in JSON mode.
# Swift's Decimal Codable expects a JSON number.
# This annotated type ensures Decimal → float in JSON output.
JsonDecimal = Annotated[Decimal, PlainSerializer(lambda v: float(v), return_type=float, when_used="json")]

T = TypeVar("T")


class APIResponse(BaseModel, Generic[T]):
    """Standard API response envelope."""

    success: bool = True
    data: T | None = None
    error: str | None = None


class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated API response envelope."""

    success: bool = True
    data: list[T]
    total: int
    page: int
    limit: int
    error: str | None = None


class ErrorResponse(BaseModel):
    """Error response body."""

    success: bool = False
    data: None = None
    error: str
