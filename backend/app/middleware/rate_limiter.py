"""In-memory sliding window rate limiting middleware."""

from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass, field

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

logger = logging.getLogger(__name__)


@dataclass
class _RateLimit:
    """Rate limit configuration for a route pattern."""

    max_requests: int
    window_seconds: int = 60


@dataclass
class _BucketEntry:
    """Sliding window bucket tracking request timestamps."""

    timestamps: list[float] = field(default_factory=list)


# Route-specific limits keyed by path prefix.
# Checked in order; first match wins.
_ROUTE_LIMITS: list[tuple[str, _RateLimit]] = [
    ("/api/v1/auth/login", _RateLimit(max_requests=5)),
    ("/api/v1/advisor/chat", _RateLimit(max_requests=20)),
    ("/api/v1/reports/", _RateLimit(max_requests=10)),
    ("/api/v1/plaid/", _RateLimit(max_requests=10)),
]
_DEFAULT_LIMIT = _RateLimit(max_requests=60)


def _match_limit(path: str) -> _RateLimit:
    """Return the rate limit config for a given request path."""
    for prefix, limit in _ROUTE_LIMITS:
        if path.startswith(prefix) or path == prefix:
            return limit
    return _DEFAULT_LIMIT


def _client_ip(request: Request) -> str:
    """Extract client IP from request, respecting X-Forwarded-For."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    client = request.client
    return client.host if client else "unknown"


class RateLimiterMiddleware(BaseHTTPMiddleware):
    """Sliding-window in-memory rate limiter.

    Keys by IP for unauthenticated requests and by user_id
    (from request state, set by AuthMiddleware) for authenticated ones.
    """

    def __init__(self, app: object) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        self._buckets: dict[str, _BucketEntry] = {}
        self._lock = asyncio.Lock()

    def _build_key(self, request: Request, limit: _RateLimit) -> str:
        """Build a bucket key from request context."""
        # Prefer user_id if present (set by AuthMiddleware)
        user_id = getattr(request.state, "user_id", None)
        identity = str(user_id) if user_id else f"ip:{_client_ip(request)}"
        return f"{identity}:{limit.max_requests}:{request.url.path}"

    def _prune_and_check(
        self, key: str, limit: _RateLimit, now: float
    ) -> tuple[bool, int]:
        """Prune expired timestamps and check if request is allowed.

        Returns (allowed, retry_after_seconds).
        """
        entry = self._buckets.get(key)
        if entry is None:
            entry = _BucketEntry()
            self._buckets[key] = entry

        window_start = now - limit.window_seconds
        # Remove timestamps outside the window
        entry.timestamps = [t for t in entry.timestamps if t > window_start]

        if len(entry.timestamps) >= limit.max_requests:
            # Earliest timestamp determines when the window reopens
            retry_after = int(entry.timestamps[0] - window_start) + 1
            return False, max(retry_after, 1)

        entry.timestamps.append(now)
        return True, 0

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        """Check rate limit before forwarding the request."""
        # Skip health checks
        if request.url.path.startswith("/health"):
            return await call_next(request)

        limit = _match_limit(request.url.path)
        key = self._build_key(request, limit)
        now = time.monotonic()

        async with self._lock:
            allowed, retry_after = self._prune_and_check(key, limit, now)

        if not allowed:
            logger.warning(
                "Rate limit exceeded for key=%s path=%s",
                key,
                request.url.path,
            )
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests"},
                headers={"Retry-After": str(retry_after)},
            )

        remaining = limit.max_requests - len(
            self._buckets.get(key, _BucketEntry()).timestamps
        )
        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(max(remaining, 0))
        return response
