"""
WebSocket handler — 실시간 도장 적립 이벤트 전송.
Redis Pub/Sub → WebSocket 브릿지.
"""

import asyncio
import json
import logging
import uuid
from collections import defaultdict

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.redis_client import get_redis

logger = logging.getLogger(__name__)
router = APIRouter()


class ConnectionManager:
    """Manages active WebSocket connections per guest_id."""

    def __init__(self):
        self.active_connections: dict[str, list[WebSocket]] = defaultdict(list)

    async def connect(self, guest_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[guest_id].append(websocket)
        logger.info(f"WS connected: {guest_id} (total: {len(self.active_connections[guest_id])})")

    def disconnect(self, guest_id: str, websocket: WebSocket):
        if guest_id in self.active_connections:
            self.active_connections[guest_id].remove(websocket)
            if not self.active_connections[guest_id]:
                del self.active_connections[guest_id]
        logger.info(f"WS disconnected: {guest_id}")

    async def send_to_guest(self, guest_id: str, message: str):
        """Send message to all connections of a guest."""
        connections = self.active_connections.get(guest_id, [])
        disconnected = []
        for ws in connections:
            try:
                await ws.send_text(message)
            except Exception:
                disconnected.append(ws)
        # Clean up dead connections
        for ws in disconnected:
            self.disconnect(guest_id, ws)


manager = ConnectionManager()


async def _redis_subscriber(guest_id: str):
    """Subscribe to Redis Pub/Sub for a specific guest and forward to WebSocket."""
    redis_client = get_redis()
    pubsub = redis_client.pubsub()
    channel = f"ws:customer:{guest_id}"

    await pubsub.subscribe(channel)
    logger.info(f"Redis subscribed to {channel}")

    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                await manager.send_to_guest(guest_id, message["data"])
    except asyncio.CancelledError:
        pass
    finally:
        await pubsub.unsubscribe(channel)
        await pubsub.close()


@router.websocket("/ws/{guest_id}")
async def websocket_endpoint(websocket: WebSocket, guest_id: str):
    """
    WebSocket endpoint for real-time stamp events.
    Customer app connects with guest_id.
    """
    await manager.connect(guest_id, websocket)

    # Start Redis subscriber task
    subscriber_task = asyncio.create_task(_redis_subscriber(guest_id))

    try:
        while True:
            # Keep connection alive, handle heartbeat
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(guest_id, websocket)
        subscriber_task.cancel()
    except Exception as e:
        logger.error(f"WS error for {guest_id}: {e}")
        manager.disconnect(guest_id, websocket)
        subscriber_task.cancel()
