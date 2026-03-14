"""JWT-based authentication service.

Includes an in-memory token blacklist for revocation.
NOTE: Production should use Redis for blacklist persistence across restarts.
"""

from __future__ import annotations

import threading
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from jwt.exceptions import PyJWTError

from app.config import get_settings

# ---------------------------------------------------------------------------
# In-memory token blacklist (JTI → expiry timestamp)
# Production should replace this with Redis for persistence across restarts.
# ---------------------------------------------------------------------------
_blacklist_lock = threading.Lock()
_blacklisted_jtis: dict[str, datetime] = {}

# ---------------------------------------------------------------------------
# In-memory concurrent session tracker (user_id → [(jti, expiry), ...])
# Ordered by creation time; oldest entry is index 0.
# Production should replace this with Redis for persistence across restarts.
# ---------------------------------------------------------------------------
_sessions_lock = threading.Lock()
_active_sessions: dict[str, list[tuple[str, datetime]]] = {}


def _cleanup_expired_entries() -> None:
    """Remove blacklist entries whose tokens have already expired.

    Called on each verify_token() invocation to prevent unbounded growth.
    Must be called while holding _blacklist_lock.
    """
    now = datetime.now(UTC)
    expired = [jti for jti, exp in _blacklisted_jtis.items() if exp <= now]
    for jti in expired:
        del _blacklisted_jtis[jti]


def blacklist_token(token: str) -> None:
    """Add a token's JTI to the blacklist.

    Extracts the JTI and expiry from the token (without verifying signature)
    and stores them so the token is rejected on future verify_token() calls.

    Args:
        token: The encoded JWT string to revoke.
    """
    try:
        payload = jwt.decode(
            token,
            options={"verify_signature": False},
            algorithms=["HS256"],
        )
    except PyJWTError:
        return  # If we can't decode it, it's already unusable

    jti = payload.get("jti")
    if jti is None:
        return  # Tokens without JTI cannot be individually revoked

    exp_ts = payload.get("exp")
    if exp_ts is not None:
        expiry = datetime.fromtimestamp(exp_ts, tz=UTC)
    else:
        # Fallback: blacklist for the default token lifetime
        settings = get_settings()
        expiry = datetime.now(UTC) + timedelta(minutes=settings.jwt_expire_minutes)

    with _blacklist_lock:
        _blacklisted_jtis[jti] = expiry


def is_token_blacklisted(jti: str) -> bool:
    """Check whether a JTI has been revoked.

    Args:
        jti: The JWT ID to check.

    Returns:
        True if the token has been blacklisted.
    """
    with _blacklist_lock:
        return jti in _blacklisted_jtis


def _register_session(user_id: str, jti: str, expiry: datetime) -> None:
    """Track a new session for user_id and evict the oldest if limit exceeded.

    Evicted JTIs are added to the blacklist so they are rejected on use.
    Acquires _sessions_lock first, then _blacklist_lock after releasing it to
    avoid lock-ordering deadlocks.

    Args:
        user_id: String representation of the user's UUID.
        jti: The JWT ID for the new token.
        expiry: The token's expiry datetime (UTC-aware).
    """
    settings = get_settings()
    to_revoke: list[tuple[str, datetime]] = []

    with _sessions_lock:
        now = datetime.now(UTC)
        sessions = [(j, e) for j, e in _active_sessions.get(user_id, []) if e > now]
        sessions.append((jti, expiry))
        while len(sessions) > settings.max_concurrent_sessions:
            to_revoke.append(sessions.pop(0))
        _active_sessions[user_id] = sessions

    # Blacklist evicted tokens outside the sessions lock to avoid deadlock
    for old_jti, old_expiry in to_revoke:
        with _blacklist_lock:
            _blacklisted_jtis[old_jti] = old_expiry


def create_access_token(user_id: uuid.UUID, *, expire_minutes: int | None = None) -> str:
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
    jti = uuid.uuid4().hex
    expiry = now + timedelta(minutes=minutes)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": expiry,
        "jti": jti,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    _register_session(str(user_id), jti, expiry)
    return token


def verify_token(token: str) -> uuid.UUID:
    """Verify a JWT token and return the user_id.

    Also checks the in-memory blacklist and cleans up expired entries.

    Args:
        token: The encoded JWT string.

    Returns:
        The user's UUID extracted from the 'sub' claim.

    Raises:
        ValueError: If the token is expired, invalid, revoked, or missing required claims.
    """
    settings = get_settings()

    # Periodic cleanup of expired blacklist entries
    with _blacklist_lock:
        _cleanup_expired_entries()

    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except PyJWTError as exc:
        raise ValueError(f"Token expired or invalid: {exc}") from exc

    # Check blacklist
    jti = payload.get("jti")
    if jti and is_token_blacklisted(jti):
        raise ValueError("Token has been revoked")

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
        # In dev mode, decode without verification
        if settings.dev_skip_auth_verification:  # TODO: production JWKS verification
            payload = jwt.decode(
                identity_token,
                options={"verify_signature": False},
                algorithms=["HS256"],
            )
        else:
            # Production: verify with Apple's public keys
            # This would fetch JWKS from https://appleid.apple.com/auth/keys
            raise NotImplementedError("Production Apple token verification not yet implemented")
    except PyJWTError as exc:
        raise ValueError(f"Invalid Apple identity token: {exc}") from exc

    if "sub" not in payload:
        raise ValueError("Apple identity token missing 'sub' claim")

    return payload


def clear_blacklist() -> None:
    """Clear the entire token blacklist. For testing only."""
    with _blacklist_lock:
        _blacklisted_jtis.clear()


def clear_sessions() -> None:
    """Clear the entire active-session tracker. For testing only."""
    with _sessions_lock:
        _active_sessions.clear()
