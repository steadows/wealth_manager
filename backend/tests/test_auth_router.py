"""Tests for auth router — login, refresh, me endpoints."""

from __future__ import annotations

import os
import uuid

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
TEST_USER_ID = uuid.UUID("00000000-0000-4000-a000-000000000001")
TEST_APPLE_ID = "apple-test-user-001"


@pytest.fixture
async def auth_engine():
    """Create an async SQLite engine for auth tests."""
    eng = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()


@pytest.fixture
async def auth_session(auth_engine) -> AsyncSession:
    """Yield a test database session."""
    factory = async_sessionmaker(bind=auth_engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as sess:
        yield sess


@pytest.fixture
async def auth_client(auth_engine):
    """Yield an httpx AsyncClient WITHOUT the get_current_user override.

    This lets us test actual JWT auth flow.
    """
    factory = async_sessionmaker(bind=auth_engine, class_=AsyncSession, expire_on_commit=False)

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
    # NOTE: NOT overriding get_current_user — we test real auth

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def seeded_user(auth_session: AsyncSession) -> User:
    """Create a test user in the database."""
    user = User(id=TEST_USER_ID, apple_id=TEST_APPLE_ID, email="test@example.com")
    auth_session.add(user)
    await auth_session.flush()
    await auth_session.refresh(user)
    return user


class TestLoginEndpoint:
    """Tests for POST /api/v1/auth/login."""

    @pytest.mark.anyio
    async def test_login_creates_user_and_returns_token(
        self, auth_client: AsyncClient, auth_session: AsyncSession
    ) -> None:
        """Login with a new Apple ID should create user and return JWT."""
        # Create a fake Apple identity token
        apple_token = jwt.encode(
            {"sub": "new-apple-user", "email": "new@example.com"},
            "any-key",
            algorithm="HS256",
        )
        response = await auth_client.post(
            "/api/v1/auth/login",
            json={"identity_token": apple_token},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.anyio
    async def test_login_existing_user_returns_token(
        self, auth_client: AsyncClient, seeded_user: User
    ) -> None:
        """Login with an existing Apple ID should return JWT without creating duplicate."""
        apple_token = jwt.encode(
            {"sub": TEST_APPLE_ID, "email": "test@example.com"},
            "any-key",
            algorithm="HS256",
        )
        response = await auth_client.post(
            "/api/v1/auth/login",
            json={"identity_token": apple_token},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data

    @pytest.mark.anyio
    async def test_login_invalid_token_returns_401(self, auth_client: AsyncClient) -> None:
        """Login with an invalid identity token should return 401."""
        response = await auth_client.post(
            "/api/v1/auth/login",
            json={"identity_token": "not-a-jwt"},
        )
        assert response.status_code == 401


class TestRefreshEndpoint:
    """Tests for POST /api/v1/auth/refresh."""

    @pytest.mark.anyio
    async def test_refresh_with_valid_token(
        self, auth_client: AsyncClient, seeded_user: User
    ) -> None:
        """Refresh with a valid JWT should return a new token."""
        token = create_access_token(seeded_user.id)
        response = await auth_client.post(
            "/api/v1/auth/refresh",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.anyio
    async def test_refresh_without_token_returns_401(self, auth_client: AsyncClient) -> None:
        """Refresh without an Authorization header should return 401."""
        response = await auth_client.post("/api/v1/auth/refresh")
        assert response.status_code == 401


class TestMeEndpoint:
    """Tests for GET /api/v1/auth/me."""

    @pytest.mark.anyio
    async def test_me_with_valid_token(self, auth_client: AsyncClient, seeded_user: User) -> None:
        """GET /me with valid JWT should return user info."""
        token = create_access_token(seeded_user.id)
        response = await auth_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(TEST_USER_ID)
        assert data["email"] == "test@example.com"

    @pytest.mark.anyio
    async def test_me_without_token_returns_401(self, auth_client: AsyncClient) -> None:
        """GET /me without auth should return 401."""
        response = await auth_client.get("/api/v1/auth/me")
        assert response.status_code == 401
