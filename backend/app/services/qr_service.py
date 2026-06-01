"""
QR Token Service — 동적 QR 토큰 생성/검증/갱신.
Redis TTL 기반 3분 유효기간.
"""

import hashlib
import json
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import redis.asyncio as redis

from app.config import get_settings

settings = get_settings()


class QRService:
    """Manages dynamic QR tokens with Redis TTL."""

    QR_PREFIX = "qr:"

    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
        self.ttl = settings.qr_token_ttl_seconds

    async def generate_token(self, guest_id: uuid.UUID) -> tuple[str, datetime]:
        """
        Generate a new QR token for the given guest_id.
        Returns (token, expires_at).
        """
        # Create a unique, secure token
        raw = f"{guest_id}:{secrets.token_urlsafe(32)}"
        token = hashlib.sha256(raw.encode()).hexdigest()[:48]

        expires_at = datetime.now(timezone.utc) + timedelta(seconds=self.ttl)

        # Store in Redis: token → guest_id mapping
        token_data = json.dumps({
            "guest_id": str(guest_id),
            "created_at": datetime.now(timezone.utc).isoformat(),
        })
        await self.redis.setex(
            f"{self.QR_PREFIX}{token}",
            self.ttl,
            token_data,
        )

        # Also invalidate any previous token for this guest
        prev_token_key = f"guest_qr:{guest_id}"
        prev_token = await self.redis.get(prev_token_key)
        if prev_token:
            await self.redis.delete(f"{self.QR_PREFIX}{prev_token}")
        await self.redis.setex(prev_token_key, self.ttl, token)

        return token, expires_at

    async def validate_token(self, token: str) -> uuid.UUID | None:
        """
        Validate a QR token and return the guest_id if valid.
        Returns None if expired or invalid.
        """
        data = await self.redis.get(f"{self.QR_PREFIX}{token}")
        if not data:
            return None

        parsed = json.loads(data)
        return uuid.UUID(parsed["guest_id"])

    async def invalidate_token(self, token: str) -> None:
        """Manually invalidate a token (e.g., after successful scan)."""
        await self.redis.delete(f"{self.QR_PREFIX}{token}")
