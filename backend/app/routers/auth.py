"""Authentication endpoints — login, refresh, logout, me."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.repositories.user_repository import UserRepository
from app.schemas.auth import LoginRequest, LoginResponse, TokenResponse, UserResponse
from app.services.auth_service import (
    blacklist_token,
    create_access_token,
    decode_apple_identity_token,
)
from app.utils.security_logger import log_auth_attempt

router = APIRouter(prefix="/auth", tags=["auth"])


def _client_ip(request: Request) -> str:
    """Extract client IP from request, preferring X-Forwarded-For."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/login", response_model=LoginResponse)
async def login(
    body: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> LoginResponse:
    """Exchange an Apple Sign-In identity token for a JWT access token.

    Decodes the Apple identity token, finds or creates the user,
    and returns a signed JWT.
    """
    ip = _client_ip(request)
    try:
        apple_claims = decode_apple_identity_token(body.identity_token)
    except ValueError as exc:
        log_auth_attempt(success=False, method="apple_login", ip=ip, reason=str(exc))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
        ) from exc

    apple_id = apple_claims["sub"]
    email = apple_claims.get("email")

    repo = UserRepository(db)
    user, _created = await repo.get_or_create_by_apple_id(apple_id, email=email)

    access_token = create_access_token(user.id)
    log_auth_attempt(success=True, method="apple_login", ip=ip, user_id=str(user.id))
    return LoginResponse(access_token=access_token)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    request: Request,
    user_id: uuid.UUID = Depends(get_current_user),
) -> TokenResponse:
    """Issue a new JWT access token for an authenticated user.

    Requires a valid Bearer token in the Authorization header.
    The old token is blacklisted upon successful refresh.
    """
    ip = _client_ip(request)

    # Blacklist the old token
    auth_header = request.headers.get("Authorization", "")
    old_token = auth_header.removeprefix("Bearer ").strip()
    if old_token:
        blacklist_token(old_token)

    new_token = create_access_token(user_id)
    log_auth_attempt(success=True, method="jwt_refresh", ip=ip, user_id=str(user_id))
    return TokenResponse(access_token=new_token)


@router.post("/logout", status_code=204)
async def logout(
    request: Request,
    user_id: uuid.UUID = Depends(get_current_user),
) -> None:
    """Logout by blacklisting the current JWT.

    The token will be rejected on subsequent verify_token() calls
    until it naturally expires and is cleaned from the blacklist.
    """
    ip = _client_ip(request)
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.removeprefix("Bearer ").strip()
    if token:
        blacklist_token(token)

    log_auth_attempt(success=True, method="logout", ip=ip, user_id=str(user_id))


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
