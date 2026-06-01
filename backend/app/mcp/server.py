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


@mcp_server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    """Execute a tool invocation from the AI agent."""
    logger.info(f"MCP tool called: {name} with args: {arguments}")

    if name == "query_store_stats":
        # In production, this would query the actual database
        return [TextContent(
            type="text",
            text=json.dumps({
                "note": "MCP tool placeholder — connect to StampService in production",
                "store_id": arguments.get("store_id"),
            }),
        )]

    elif name == "query_customer_segments":
        return [TextContent(
            type="text",
            text=json.dumps({
                "note": "MCP tool placeholder — implement segmentation query",
                "store_id": arguments.get("store_id"),
                "segment": arguments.get("segment", "all"),
            }),
        )]

    elif name == "send_targeted_push":
        return [TextContent(
            type="text",
            text=json.dumps({
                "note": "MCP tool placeholder — integrate with FCMService",
                "status": "queued",
            }),
        )]

    return [TextContent(type="text", text=f"Unknown tool: {name}")]


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
