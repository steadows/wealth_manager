"""JWT authentication middleware (Sprint 3 stub — pass-through)."""

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response


class AuthMiddleware(BaseHTTPMiddleware):
    """JWT authentication middleware.

    Sprint 3: pass-through — does not validate tokens.
    Will be implemented with real JWT validation in Sprint 4.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Pass request through without authentication checks."""
        return await call_next(request)
