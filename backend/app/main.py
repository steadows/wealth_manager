"""FastAPI application factory."""

import uuid
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.middleware.auth import AuthMiddleware
from app.middleware.rate_limiter import RateLimiterMiddleware
from app.routers import (
    accounts,
    advisory,
    auth,
    goals,
    health,
    plaid,
    sync,
    transactions,
    webhooks,
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application startup and shutdown lifecycle."""
    # Startup: could initialize DB pool, Redis connection, etc.
    yield
    # Shutdown: cleanup resources


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    settings = get_settings()

    is_prod = settings.environment == "production"
    app = FastAPI(
        title="Wealth Manager API",
        version="0.1.0",
        description="Personal CFO backend service",
        lifespan=lifespan,
        docs_url=None if is_prod else "/docs",
        redoc_url=None if is_prod else "/redoc",
        openapi_url=None if is_prod else "/openapi.json",
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept", "X-Request-ID"],
    )

    # Security headers middleware
    @app.middleware("http")
    async def add_security_headers(request: Request, call_next):  # noqa: ARG001
        """Add security headers to all responses."""
        response = await call_next(request)
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
        )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Cache-Control"] = "no-store"
        return response

    # Request ID middleware — runs before security headers (LIFO stack)
    @app.middleware("http")
    async def add_request_id(request: Request, call_next):
        """Attach a unique request ID to each request and response."""
        request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    # Custom middleware
    app.add_middleware(AuthMiddleware)
    app.add_middleware(RateLimiterMiddleware)

    # Health routes at root level
    app.include_router(health.router)

    # API v1 routes
    app.include_router(auth.router, prefix="/api/v1")
    app.include_router(accounts.router, prefix="/api/v1")
    app.include_router(transactions.router, prefix="/api/v1")
    app.include_router(plaid.router, prefix="/api/v1")
    app.include_router(webhooks.router, prefix="/api/v1")
    app.include_router(sync.router, prefix="/api/v1")
    app.include_router(advisory.router, prefix="/api/v1")
    app.include_router(goals.router, prefix="/api/v1")

    return app


app = create_app()
