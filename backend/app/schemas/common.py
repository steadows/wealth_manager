"""Common/shared Pydantic schemas."""

from typing import Generic, TypeVar

from pydantic import BaseModel

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
