"""
Agent Scheduler — automation_mode=auto 매장의 AI 에이전트를 주기 실행.

운영에선 외부 cron/worker가 더 견고하지만, MVP는 앱 내 asyncio 루프로 충분.
settings.agent_scheduler_enabled=true일 때만 lifespan에서 기동된다.
"""

import asyncio
import logging

from sqlalchemy import select

from app.config import get_settings
from app.database import async_session
from app.models.agent_policy import AgentPolicy, AutomationMode
from app.services.agent_service import AgentService

logger = logging.getLogger(__name__)
settings = get_settings()


async def run_all_auto_stores(redis_client=None) -> dict:
    """automation_mode=auto 인 모든 매장에 대해 에이전트 1회 실행."""
    summary = {"stores": 0, "issued": 0, "errors": 0}
    async with async_session() as db:
        store_ids = (
            await db.execute(
                select(AgentPolicy.store_id).where(
                    AgentPolicy.automation_mode == AutomationMode.AUTO.value
                )
            )
        ).scalars().all()

    for store_id in store_ids:
        try:
            async with async_session() as db:
                agent = AgentService(db, redis_client)
                result = await agent.run_pass(store_id)
                await db.commit()
                summary["stores"] += 1
                summary["issued"] += result.get("issued", 0)
        except Exception as e:  # noqa: BLE001
            summary["errors"] += 1
            logger.error(f"Agent run failed for store {store_id}: {e}")
    logger.info(f"Agent scheduler pass complete: {summary}")
    return summary


async def agent_scheduler_loop() -> None:
    """주기적으로 run_all_auto_stores를 호출하는 백그라운드 루프."""
    interval = settings.agent_scheduler_interval_seconds
    logger.info(f"🤖 Agent scheduler started (every {interval}s)")
    # 부팅 직후 즉시 실행하지 않고 한 주기 대기 (워밍업)
    while True:
        try:
            await asyncio.sleep(interval)
            from app.redis_client import get_redis

            try:
                redis_client = get_redis()
            except Exception:
                redis_client = None
            await run_all_auto_stores(redis_client)
        except asyncio.CancelledError:
            logger.info("🛑 Agent scheduler stopped")
            break
        except Exception as e:  # noqa: BLE001
            logger.error(f"Agent scheduler loop error: {e}")
