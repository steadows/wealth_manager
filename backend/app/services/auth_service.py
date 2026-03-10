"""JWT-based authentication service."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from jose import JWTError, jwt

from app.config import get_settings


def create_access_token(
    user_id: uuid.UUID, *, expire_minutes: int | None = None
) -> str:
    """Create a JWT access token for the given user.

    Args:
        user_id: The user's UUID to encode as the 'sub' claim.
        expire_minutes: Override for token lifetime. Defaults to settings value.

    Returns:
        Encoded JWT string.
    """
    settings = get_settings()
    minutes = expire_minutes if expire_minutes is not None else settings.jwt_expire_minutes
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(minutes=minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def verify_token(token: str) -> uuid.UUID:
    """Verify a JWT token and return the user_id.

    Args:
        token: The encoded JWT string.

    Returns:
        The user's UUID extracted from the 'sub' claim.

    Raises:
        ValueError: If the token is expired, invalid, or missing required claims.
    """
    settings = get_settings()
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except JWTError as exc:
        raise ValueError(f"Token expired or invalid: {exc}") from exc

    sub = payload.get("sub")
    if sub is None:
        raise ValueError("Token expired or invalid: missing sub claim")

    try:
        return uuid.UUID(sub)
    except (ValueError, AttributeError) as exc:
        raise ValueError(f"Token expired or invalid: bad sub format: {exc}") from exc


def decode_apple_identity_token(identity_token: str) -> dict:
    """Decode an Apple Sign-In identity token.

    In sandbox mode, accepts any token and extracts claims without
    cryptographic verification. In production, this should verify
    against Apple's JWKS endpoint.

    Args:
        identity_token: The JWT identity token from Apple Sign-In.

    Returns:
        Dict containing at minimum the 'sub' and optionally 'email' claims.

    Raises:
        ValueError: If the token cannot be decoded or is missing the 'sub' claim.
    """
    settings = get_settings()
    try:
        # In sandbox mode, decode without verification
        if settings.plaid_env == "sandbox":  # TODO: production JWKS verification
            payload = jwt.get_unverified_claims(identity_token)
        else:
            # Production: verify with Apple's public keys
            # This would fetch JWKS from https://appleid.apple.com/auth/keys
            raise NotImplementedError("Production Apple token verification not yet implemented")
    except JWTError as exc:
        raise ValueError(f"Invalid Apple identity token: {exc}") from exc

    if "sub" not in payload:
        raise ValueError("Apple identity token missing 'sub' claim")

    return payload
