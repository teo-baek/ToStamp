"""
Pytest 공용 픽스처 — 테스트 전용 SQLite DB + FakeRedis 격리.

DATABASE_URL/REDIS_URL은 app.config(Settings)가 임포트되기 전에
설정해야 하므로 이 모듈 최상단에서 환경변수를 덮어쓴다.
"""

import os
import pathlib

_TEST_DB = "tostamp_test.db"
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///./{_TEST_DB}"
os.environ["DEBUG"] = "false"  # SQL echo 끄기
# 닫힌 포트 → init_redis가 FakeRedis로 즉시 폴백
os.environ["REDIS_URL"] = "redis://127.0.0.1:65535/0"

import pytest
from httpx import ASGITransport, AsyncClient


def pytest_sessionstart(session):
    """이전 실행의 테스트 DB 제거 (격리 보장)."""
    db_path = pathlib.Path(_TEST_DB)
    if db_path.exists():
        db_path.unlink()


@pytest.fixture(autouse=True)
async def _infra():
    """테이블 생성 + FakeRedis 초기화 (멱등) — lifespan 미실행 보완."""
    import app.models  # noqa: F401 — 전체 모델 메타데이터 등록

    from app import redis_client as rc
    from app.database import Base, engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    if rc.redis_client is None:
        await rc.init_redis()
    yield


@pytest.fixture
async def client():
    """Async test client."""
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
