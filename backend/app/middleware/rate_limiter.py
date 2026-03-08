"""Rate limiting middleware (Sprint 3 stub)."""

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response


class RateLimiterMiddleware(BaseHTTPMiddleware):
    """Rate limiting middleware.

    Sprint 3: pass-through — no rate limiting enforced.
    Will use Redis-backed sliding window in Sprint 4.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Pass request through without rate limiting."""
        return await call_next(request)
