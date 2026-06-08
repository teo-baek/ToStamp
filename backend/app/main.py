"""
ToStamp API — FastAPI 메인 엔트리포인트.
비동기 처리 최적화, 실시간 WebSocket 지원.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.redis_client import close_redis, init_redis

settings = get_settings()
logger = logging.getLogger(__name__)

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup/shutdown lifecycle."""
    # Startup
    logger.info("🚀 ToStamp API starting...")

    # Auto-create tables for SQLite dev mode
    if settings.database_url.startswith("sqlite"):
        from app.database import engine, Base
        from app.models.store import Store  # noqa: F401
        from app.models.customer import Customer  # noqa: F401
        from app.models.stamp_card import StampCard  # noqa: F401
        from app.models.visit import Visit  # noqa: F401
        from app.models.coupon import Coupon  # noqa: F401
        from app.models.agent_policy import (  # noqa: F401
            AgentActionLog,
            AgentPolicy,
        )
        from app.models.money import (  # noqa: F401
            MoneyAccount,
            MoneyTransaction,
            StorePayable,
        )
        from app.models.marketplace import MarketplaceListing  # noqa: F401
        from app.models.affiliate import (  # noqa: F401
            AffiliateGroup,
            AffiliateMember,
            CoStampClaim,
            CoStampEvent,
            CrossPromo,
        )
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("✅ SQLite tables created")

    await init_redis()

    # Optional: AI marketing agent scheduler (auto-run for automation_mode=auto)
    scheduler_task = None
    if settings.agent_scheduler_enabled:
        import asyncio

        from app.services.scheduler import agent_scheduler_loop

        scheduler_task = asyncio.create_task(agent_scheduler_loop())

    logger.info(f"✅ ToStamp API v{settings.app_version} ready")

    yield

    # Shutdown
    logger.info("🛑 ToStamp API shutting down...")
    if scheduler_task is not None:
        scheduler_task.cancel()
    await close_redis()
    logger.info("✅ Cleanup complete")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="소상공인을 위한 지능형 마케팅 에이전트 서비스",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API v1 routers
from app.api.v1.auth import router as auth_router
from app.api.v1.stamps import router as stamps_router
from app.api.v1.stores import router as stores_router
from app.api.v1.customers import router as customers_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.marketing import router as marketing_router
from app.api.v1.exchange import router as exchange_router
from app.api.v1.affiliate import router as affiliate_router
from app.api.websocket import router as ws_router

app.include_router(auth_router, prefix=settings.api_prefix)
app.include_router(stamps_router, prefix=settings.api_prefix)
app.include_router(stores_router, prefix=settings.api_prefix)
app.include_router(customers_router, prefix=settings.api_prefix)
app.include_router(notifications_router, prefix=settings.api_prefix)
app.include_router(marketing_router, prefix=settings.api_prefix)
app.include_router(exchange_router, prefix=settings.api_prefix)
app.include_router(affiliate_router, prefix=settings.api_prefix)
app.include_router(ws_router)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "version": settings.app_version,
        "service": "tostamp-api",
    }
