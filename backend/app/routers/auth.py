"""Authentication endpoints — login, refresh, me."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.repositories.user_repository import UserRepository
from app.schemas.auth import LoginRequest, LoginResponse, TokenResponse, UserResponse
from app.services.auth_service import (
    create_access_token,
    decode_apple_identity_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
async def login(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    """Exchange an Apple Sign-In identity token for a JWT access token.

    Decodes the Apple identity token, finds or creates the user,
    and returns a signed JWT.
    """
    try:
        apple_claims = decode_apple_identity_token(body.identity_token)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid identity token: {exc}",
        ) from exc

    apple_id = apple_claims["sub"]
    email = apple_claims.get("email")

    repo = UserRepository(db)
    user, _created = await repo.get_or_create_by_apple_id(apple_id, email=email)

    access_token = create_access_token(user.id)
    return LoginResponse(access_token=access_token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    request: Request,
    user_id: uuid.UUID = Depends(get_current_user),
) -> TokenResponse:
    """Issue a new JWT access token for an authenticated user.

    Requires a valid Bearer token in the Authorization header.
    """
    new_token = create_access_token(user_id)
    return TokenResponse(access_token=new_token)


@router.get("/me", response_model=UserResponse)
async def me(
    user_id: uuid.UUID = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    """Return the current authenticated user's information."""
    repo = UserRepository(db)
    user = await repo.get_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserResponse.model_validate(user)
