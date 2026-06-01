"""
API Unit Tests — 핵심 API 엔드포인트 테스트.
"""

import uuid
import pytest
from httpx import AsyncClient, ASGITransport

from app.main import app


@pytest.fixture
async def client():
    """Async test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Health endpoint returns healthy status."""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "tostamp-api"


@pytest.mark.asyncio
async def test_guest_registration(client: AsyncClient):
    """Guest registration returns UUID and QR token."""
    response = await client.post("/api/v1/auth/guest")
    assert response.status_code == 200
    data = response.json()
    assert "customer_id" in data
    assert "guest_id" in data
    assert "qr_token" in data
    assert len(data["qr_token"]) > 0


@pytest.mark.asyncio
async def test_store_creation(client: AsyncClient):
    """Store creation works with valid data."""
    response = await client.post(
        "/api/v1/stores/",
        json={
            "owner_phone": "010-1234-5678",
            "store_name": "테스트 카페",
            "stamp_goal": 10,
            "reward_description": "무료 아메리카노 1잔",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["store_name"] == "테스트 카페"
    assert data["stamp_goal"] == 10
