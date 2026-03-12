"""FastAPI application factory."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.middleware.auth import AuthMiddleware
from app.middleware.rate_limiter import RateLimiterMiddleware
from app.routers import accounts, advisory, auth, health, plaid, sync, transactions, webhooks


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application startup and shutdown lifecycle."""
    # Startup: could initialize DB pool, Redis connection, etc.
    yield
    # Shutdown: cleanup resources


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    settings = get_settings()

    app = FastAPI(
        title="Wealth Manager API",
        version="0.1.0",
        description="Personal CFO backend service",
        lifespan=lifespan,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

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

    return app


app = create_app()
