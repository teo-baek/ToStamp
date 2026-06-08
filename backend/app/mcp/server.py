"""
MCP Server — Model Context Protocol for AI agent database access.
Provides standardized tools and resources for the marketing AI agent.
"""

import json
import logging
from typing import Any

from mcp.server import Server
from mcp.types import Resource, Tool, TextContent

logger = logging.getLogger(__name__)

# MCP Server instance
mcp_server = Server("tostamp-mcp")


# ── Tools: AI agent can invoke these ──────────────────────────────

@mcp_server.list_tools()
async def list_tools() -> list[Tool]:
    """Define tools available to the AI marketing agent."""
    return [
        Tool(
            name="query_store_stats",
            description="매장의 오늘 통계(적립 수, 신규/재방문 고객, 혜택 임박)를 조회합니다.",
            inputSchema={
                "type": "object",
                "properties": {
                    "store_id": {
                        "type": "string",
                        "description": "매장 UUID"
                    }
                },
                "required": ["store_id"],
            },
        ),
        Tool(
            name="query_customer_segments",
            description="매장 고객을 세그먼트별로 분류합니다 (신규, 단골, 이탈 위험).",
            inputSchema={
                "type": "object",
                "properties": {
                    "store_id": {
                        "type": "string",
                        "description": "매장 UUID"
                    },
                    "segment": {
                        "type": "string",
                        "enum": ["new", "loyal", "at_risk", "all"],
                        "description": "조회할 세그먼트"
                    }
                },
                "required": ["store_id"],
            },
        ),
        Tool(
            name="send_targeted_push",
            description="특정 고객 세그먼트에 타겟 푸시 알림을 발송합니다.",
            inputSchema={
                "type": "object",
                "properties": {
                    "store_id": {"type": "string"},
                    "segment": {
                        "type": "string",
                        "enum": ["near_reward", "inactive_7d", "all"],
                    },
                    "title": {"type": "string"},
                    "body": {"type": "string"},
                },
                "required": ["store_id", "segment", "title", "body"],
            },
        ),
    ]


def _json(payload: dict) -> list[TextContent]:
    return [TextContent(type="text", text=json.dumps(payload, default=str, ensure_ascii=False))]


@mcp_server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    """Execute a tool invocation from the AI agent (wired to real services)."""
    import uuid as _uuid

    from app.database import async_session
    from app.services.agent_service import AgentService
    from app.services.segmentation_service import SegmentationService
    from app.services.stamp_service import StampService

    logger.info(f"MCP tool called: {name} with args: {arguments}")

    try:
        store_id = _uuid.UUID(str(arguments["store_id"]))
    except (KeyError, ValueError):
        return _json({"error": "valid store_id (UUID) is required"})

    try:
        redis_client = None
        try:
            from app.redis_client import get_redis
            redis_client = get_redis()
        except Exception:
            pass

        async with async_session() as db:
            if name == "query_store_stats":
                stats = await StampService(db, redis_client).get_store_dashboard(store_id)
                return _json({"store_id": str(store_id), "stats": stats})

            elif name == "query_customer_segments":
                seg = SegmentationService(db)
                segment = arguments.get("segment", "all")
                if segment in ("all", None):
                    return _json({
                        "store_id": str(store_id),
                        "counts": await seg.get_segment_counts(store_id),
                    })
                members = await seg.get_segment(store_id, segment)
                return _json({
                    "store_id": str(store_id),
                    "segment": segment,
                    "count": len(members),
                    "customers": [
                        {"display_name": m.display_name, "visits": m.visits,
                         "days_since_last": m.days_since_last}
                        for m in members[:50]
                    ],
                })

            elif name == "send_targeted_push":
                # 자율 에이전트 1회 실행으로 위임 (예산 한도 내 복귀 도장).
                summary = await AgentService(db, redis_client).run_pass(store_id)
                await db.commit()
                return _json({"store_id": str(store_id), "result": summary})

        return _json({"error": f"Unknown tool: {name}"})
    except Exception as e:
        logger.error(f"MCP tool {name} failed: {e}")
        return _json({"error": str(e)})


# ── Resources: Read-only context for the AI ────────────────────────

@mcp_server.list_resources()
async def list_resources() -> list[Resource]:
    """Define read-only resources available to the AI."""
    return [
        Resource(
            uri="tostamp://schema/database",
            name="Database Schema",
            description="ToStamp 데이터베이스 스키마 정보",
            mimeType="application/json",
        ),
    ]


@mcp_server.read_resource()
async def read_resource(uri: str) -> str:
    """Read a resource by URI."""
    if uri == "tostamp://schema/database":
        return json.dumps({
            "tables": {
                "stores": "매장 정보 (이름, 도장 목표, 리워드)",
                "customers": "고객 정보 (게스트ID, 카카오ID, FCM토큰)",
                "stamp_cards": "스탬프 카드 (고객-매장 연결, 현재 도장 수)",
                "visits": "방문 기록 (도장 적립 이력)",
                "coupons": "쿠폰 (상태: 사용가능/사용완료/만료)",
            },
        })
    return json.dumps({"error": f"Resource not found: {uri}"})
