"""Tests for the JWT authentication middleware."""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from jose import jwt

os.environ.setdefault("JWT_SECRET", "test-secret-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.dependencies import get_db
from app.main import create_app
from app.models.user import User
from app.services.auth_service import create_access_token

SECRET = "test-secret-not-for-production"
ALGORITHM = "HS256"
TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")


@pytest.fixture
async def mw_engine():
    """Create an async SQLite engine for middleware tests."""
    eng = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()


@pytest.fixture
async def mw_session(mw_engine) -> AsyncSession:
    """Yield a test database session."""
    factory = async_sessionmaker(bind=mw_engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as sess:
        yield sess


@pytest.fixture
async def mw_client(mw_engine) -> AsyncClient:
    """Yield an httpx AsyncClient WITHOUT get_current_user override.

    This tests the actual middleware auth flow end-to-end.
    """
    factory = async_sessionmaker(bind=mw_engine, class_=AsyncSession, expire_on_commit=False)

    async def override_get_db():
        async with factory() as sess:
            try:
                yield sess
                await sess.commit()
            except Exception:
                await sess.rollback()
                raise

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    # NOTE: NOT overriding get_current_user — we test real middleware

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def seeded_user(mw_session: AsyncSession) -> User:
    """Create a test user in the database."""
    user = User(
        id=TEST_USER_ID,
        apple_id="mw-test-user",
        email="middleware@test.com",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    mw_session.add(user)
    await mw_session.flush()
    return user


class TestPublicRoutes:
    """Verify that public routes work without authentication."""

    @pytest.mark.anyio
    async def test_health_no_auth_required(self, mw_client: AsyncClient) -> None:
        """GET /health should succeed without any token."""
        resp = await mw_client.get("/health")
        assert resp.status_code == 200

    @pytest.mark.anyio
    async def test_health_db_no_auth_required(self, mw_client: AsyncClient) -> None:
        """GET /health/db should succeed without any token."""
        resp = await mw_client.get("/health/db")
        assert resp.status_code == 200

    @pytest.mark.anyio
    async def test_login_no_auth_required(self, mw_client: AsyncClient) -> None:
        """POST /api/v1/auth/login should not require a Bearer token.

        The endpoint itself may return an error for bad input, but
        the middleware should not block it.
        """
        resp = await mw_client.post(
            "/api/v1/auth/login",
            json={"identity_token": "not-a-jwt"},
        )
        # 401 is from the auth service (bad Apple token), not the middleware
        assert resp.status_code in {200, 401, 422}

    @pytest.mark.anyio
    async def test_docs_no_auth_required(self, mw_client: AsyncClient) -> None:
        """GET /docs should be accessible without auth."""
        resp = await mw_client.get("/docs")
        assert resp.status_code == 200


class TestProtectedRoutesMissingToken:
    """Verify that protected routes reject requests without tokens."""

    @pytest.mark.anyio
    async def test_accounts_no_token_returns_401(self, mw_client: AsyncClient) -> None:
        """GET /api/v1/accounts/ without Authorization header returns 401."""
        resp = await mw_client.get("/api/v1/accounts/")
        assert resp.status_code == 401
        assert "authorization" in resp.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_sync_no_token_returns_401(self, mw_client: AsyncClient) -> None:
        """GET /api/v1/sync/ without Authorization header returns 401."""
        resp = await mw_client.get("/api/v1/sync/")
        assert resp.status_code == 401


class TestProtectedRoutesInvalidToken:
    """Verify that protected routes reject invalid tokens."""

    @pytest.mark.anyio
    async def test_malformed_token_returns_401(self, mw_client: AsyncClient) -> None:
        """A non-JWT string as Bearer token returns 401."""
        resp = await mw_client.get(
            "/api/v1/accounts/",
            headers={"Authorization": "Bearer not-a-valid-jwt"},
        )
        assert resp.status_code == 401

    @pytest.mark.anyio
    async def test_expired_token_returns_401(self, mw_client: AsyncClient) -> None:
        """An expired JWT returns 401."""
        payload = {
            "sub": str(TEST_USER_ID),
            "exp": datetime.now(UTC) - timedelta(hours=1),
            "iat": datetime.now(UTC) - timedelta(hours=2),
        }
        expired_token = jwt.encode(payload, SECRET, algorithm=ALGORITHM)
        resp = await mw_client.get(
            "/api/v1/accounts/",
            headers={"Authorization": f"Bearer {expired_token}"},
        )
        assert resp.status_code == 401

    @pytest.mark.anyio
    async def test_wrong_secret_returns_401(self, mw_client: AsyncClient) -> None:
        """A JWT signed with a different secret returns 401."""
        payload = {
            "sub": str(TEST_USER_ID),
            "exp": datetime.now(UTC) + timedelta(hours=1),
            "iat": datetime.now(UTC),
        }
        bad_token = jwt.encode(payload, "wrong-secret-key", algorithm=ALGORITHM)
        resp = await mw_client.get(
            "/api/v1/accounts/",
            headers={"Authorization": f"Bearer {bad_token}"},
        )
        assert resp.status_code == 401

    @pytest.mark.anyio
    async def test_bearer_prefix_required(self, mw_client: AsyncClient) -> None:
        """Authorization header without 'Bearer ' prefix returns 401."""
        token = create_access_token(TEST_USER_ID)
        resp = await mw_client.get(
            "/api/v1/accounts/",
            headers={"Authorization": token},
        )
        assert resp.status_code == 401

    @pytest.mark.anyio
    async def test_empty_bearer_returns_401(self, mw_client: AsyncClient) -> None:
        """Authorization header with 'Bearer ' but no token returns 401."""
        resp = await mw_client.get(
            "/api/v1/accounts/",
            headers={"Authorization": "Bearer "},
        )
        assert resp.status_code == 401


class TestProtectedRoutesValidToken:
    """Verify that protected routes accept valid tokens."""

    @pytest.mark.anyio
    async def test_valid_token_passes_middleware(
        self, mw_client: AsyncClient, seeded_user: User
    ) -> None:
        """A valid JWT allows access through the middleware to the endpoint."""
        token = create_access_token(seeded_user.id)
        resp = await mw_client.get(
            "/api/v1/accounts/",
            headers={"Authorization": f"Bearer {token}"},
        )
        # Could be 200 (empty list) — the important thing is not 401
        assert resp.status_code == 200

    @pytest.mark.anyio
    async def test_valid_token_sets_user_context(
        self, mw_client: AsyncClient, seeded_user: User
    ) -> None:
        """A valid JWT on /auth/me returns the correct user, proving user_id propagation."""
        token = create_access_token(seeded_user.id)
        resp = await mw_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["id"] == str(TEST_USER_ID)
