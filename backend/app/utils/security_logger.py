"""Structured security event logging.

Provides consistent, structured logging for security-relevant events
across the backend: authentication, authorization, and data access.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

security_logger = logging.getLogger("security")


def log_auth_attempt(
    *,
    success: bool,
    method: str,
    ip: str,
    user_id: str | None = None,
    reason: str | None = None,
) -> None:
    """Log an authentication attempt (success or failure).

    Args:
        success: Whether authentication succeeded.
        method: Auth method used (e.g. "apple_login", "jwt_refresh").
        ip: Client IP address.
        user_id: User ID if known.
        reason: Failure reason if applicable.
    """
    level = logging.INFO if success else logging.WARNING
    security_logger.log(
        level,
        "auth_attempt",
        extra={
            "event": "auth_attempt",
            "success": success,
            "method": method,
            "ip": ip,
            "user_id": user_id,
            "reason": reason,
            "timestamp": datetime.now(UTC).isoformat(),
        },
    )


def log_auth_failure(*, ip: str, reason: str) -> None:
    """Log an authentication failure (middleware-level rejection).

    Args:
        ip: Client IP address.
        reason: Why authentication was rejected.
    """
    security_logger.warning(
        "auth_failure",
        extra={
            "event": "auth_failure",
            "ip": ip,
            "reason": reason,
            "timestamp": datetime.now(UTC).isoformat(),
        },
    )


def log_data_access(*, user_id: str, resource: str, action: str) -> None:
    """Log a data access event.

    Args:
        user_id: The authenticated user performing the action.
        resource: The resource being accessed (e.g. "account", "transaction").
        action: The action performed (e.g. "create", "delete", "list").
    """
    security_logger.info(
        "data_access",
        extra={
            "event": "data_access",
            "user_id": user_id,
            "resource": resource,
            "action": action,
            "timestamp": datetime.now(UTC).isoformat(),
        },
    )


def log_token_exchange(*, user_id: str, provider: str, ip: str) -> None:
    """Log a third-party token exchange (e.g. Plaid) without sensitive values.

    Args:
        user_id: The authenticated user.
        provider: The provider (e.g. "plaid").
        ip: Client IP address.
    """
    security_logger.info(
        "token_exchange",
        extra={
            "event": "token_exchange",
            "user_id": user_id,
            "provider": provider,
            "ip": ip,
            "timestamp": datetime.now(UTC).isoformat(),
        },
    )
