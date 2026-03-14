"""JWT authentication middleware."""

from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.services.auth_service import verify_token

# Paths that do not require authentication
_PUBLIC_PATHS = frozenset(
    {
        "/health",
        "/docs",
        "/openapi.json",
        "/redoc",
        "/api/v1/auth/login",
        "/api/v1/webhooks/plaid",
    }
)

# Path prefixes that do not require authentication
_PUBLIC_PREFIXES = (
    "/docs",
    "/openapi",
    "/redoc",
    "/health",
)


class AuthMiddleware(BaseHTTPMiddleware):
    """JWT authentication middleware.

    Skips auth for public paths (health, docs, login, webhooks).
    For all other routes, extracts and verifies the Bearer token
    and sets request.state.user_id.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Validate JWT for protected routes."""
        path = request.url.path

        # Skip auth for public paths
        if path in _PUBLIC_PATHS or any(path.startswith(p) for p in _PUBLIC_PREFIXES):
            return await call_next(request)

        # Extract Bearer token
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=401,
                content={"detail": "Missing or invalid authorization header"},
            )

        token = auth_header.removeprefix("Bearer ").strip()
        try:
            user_id = verify_token(token)
        except ValueError:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid or expired token"},
            )

        # Attach user_id to request state for downstream use
        request.state.user_id = user_id
        return await call_next(request)
