"""Health endpoint tests."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_returns_healthy(client: AsyncClient) -> None:
    """GET /health should return status healthy."""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


@pytest.mark.asyncio
async def test_health_db_returns_connected(client: AsyncClient) -> None:
    """GET /health/db should report database connected."""
    response = await client.get("/health/db")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"


@pytest.mark.asyncio
async def test_health_redis_returns_not_configured(client: AsyncClient) -> None:
    """GET /health/redis should report redis not configured (Sprint 3 stub)."""
    response = await client.get("/health/redis")
    assert response.status_code == 200
    data = response.json()
    assert data["redis"] == "not_configured"
