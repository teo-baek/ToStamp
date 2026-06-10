"""
Redis client for caching, QR token management, and Pub/Sub messaging.
Falls back to in-memory dict when Redis is unavailable (local dev).
"""

import logging
from typing import Any

import redis.asyncio as redis

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

redis_client: redis.Redis | None = None
_use_fake = False


class FakeRedis:
    """In-memory Redis substitute for local development without Redis."""

    def __init__(self):
        self._store: dict[str, Any] = {}
        self._ttls: dict[str, float] = {}
        self._pubsub_callbacks: dict[str, list] = {}

    async def ping(self):
        return True

    async def setex(self, key: str, ttl: int, value: str):
        self._store[key] = value
        self._ttls[key] = ttl

    async def get(self, key: str) -> str | None:
        return self._store.get(key)

    async def getdel(self, key: str) -> str | None:
        self._ttls.pop(key, None)
        return self._store.pop(key, None)

    async def delete(self, *keys: str):
        for key in keys:
            self._store.pop(key, None)

    async def publish(self, channel: str, message: str):
        logger.debug(f"FakeRedis PUBLISH {channel}: {message[:80]}...")

    def pubsub(self):
        return FakePubSub()

    async def close(self):
        self._store.clear()


class FakePubSub:
    """Fake PubSub for local development."""

    async def subscribe(self, channel: str):
        logger.debug(f"FakeRedis SUBSCRIBE {channel}")

    async def unsubscribe(self, channel: str):
        pass

    async def close(self):
        pass

    async def listen(self):
        # Never yields — keeps WebSocket alive without events
        import asyncio
        while True:
            await asyncio.sleep(3600)
            yield {"type": "heartbeat", "data": ""}


async def init_redis() -> redis.Redis | FakeRedis:
    """Initialize Redis connection pool. Falls back to FakeRedis if unavailable."""
    global redis_client, _use_fake

    try:
        client = redis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
            max_connections=50,
            socket_connect_timeout=2,
        )
        await client.ping()
        redis_client = client
        logger.info("✅ Redis connected")
        return redis_client
    except Exception as e:
        logger.warning(f"⚠️  Redis unavailable ({e}). Using in-memory fallback.")
        _use_fake = True
        redis_client = FakeRedis()
        return redis_client


async def close_redis() -> None:
    """Close Redis connection pool."""
    global redis_client
    if redis_client:
        await redis_client.close()
        redis_client = None


def get_redis() -> redis.Redis | FakeRedis:
    """Dependency: returns the Redis client instance."""
    if redis_client is None:
        raise RuntimeError("Redis not initialized. Call init_redis() first.")
    return redis_client
