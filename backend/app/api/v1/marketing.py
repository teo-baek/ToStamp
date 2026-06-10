"""
Marketing API — 고객 세그먼트, 단골 TOP, AI 마케팅 에이전트(정책/실행).
사장님 대시보드와 Premium 자율 에이전트의 진입점.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.agent_policy import AutomationMode
from app.redis_client import get_redis
from app.schemas.marketing import (
    AgentPolicyResponse,
    AgentPolicyUpdate,
    AgentReportResponse,
    AgentRunResponse,
    CustomerProfileResponse,
    SegmentCountsResponse,
)
from app.services.agent_service import AgentService
from app.services.scheduler import run_all_auto_stores
from app.services.segmentation_service import SegmentationService

router = APIRouter(prefix="/marketing", tags=["marketing"])

_VALID_SEGMENTS = {"new", "loyal", "at_risk", "near_reward", "churned"}


def _to_profile_response(p) -> CustomerProfileResponse:
    return CustomerProfileResponse(
        customer_id=p.customer_id,
        display_name=p.display_name,
        visits=p.visits,
        max_stamps=p.max_stamps,
        last_visit=p.last_visit,
        days_since_last=p.days_since_last,
        segments=p.segments,
    )


@router.get(
    "/stores/{store_id}/segments", response_model=SegmentCountsResponse
)
async def get_segment_counts(
    store_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """세그먼트별 고객 수 (신규/단골/이탈위험/임박/이탈)."""
    seg = SegmentationService(db)
    counts = await seg.get_segment_counts(store_id)
    return SegmentCountsResponse(**counts)


@router.get(
    "/stores/{store_id}/segments/{segment}",
    response_model=list[CustomerProfileResponse],
)
async def get_segment_members(
    store_id: uuid.UUID,
    segment: str,
    db: AsyncSession = Depends(get_db),
):
    """특정 세그먼트에 속한 고객 목록."""
    if segment not in _VALID_SEGMENTS:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown segment. Valid: {sorted(_VALID_SEGMENTS)}",
        )
    seg = SegmentationService(db)
    profiles = await seg.get_segment(store_id, segment)
    return [_to_profile_response(p) for p in profiles]


@router.get(
    "/stores/{store_id}/top-customers",
    response_model=list[CustomerProfileResponse],
)
async def get_top_customers(
    store_id: uuid.UUID,
    limit: int = 5,
    db: AsyncSession = Depends(get_db),
):
    """단골 TOP 고객 (방문 횟수 순)."""
    seg = SegmentationService(db)
    profiles = await seg.get_top_customers(store_id, limit=limit)
    return [_to_profile_response(p) for p in profiles]


@router.get(
    "/stores/{store_id}/agent/policy", response_model=AgentPolicyResponse
)
async def get_agent_policy(
    store_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """매장 AI 에이전트 정책 조회 (없으면 기본값 생성)."""
    agent = AgentService(db, redis_client)
    policy = await agent.get_or_create_policy(store_id)
    return policy


@router.put(
    "/stores/{store_id}/agent/policy", response_model=AgentPolicyResponse
)
async def update_agent_policy(
    store_id: uuid.UUID,
    request: AgentPolicyUpdate,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """AI 에이전트 예산/자동화 모드 설정."""
    agent = AgentService(db, redis_client)
    policy = await agent.get_or_create_policy(store_id)

    data = request.model_dump(exclude_unset=True)
    if "automation_mode" in data:
        valid = {m.value for m in AutomationMode}
        if data["automation_mode"] not in valid:
            raise HTTPException(
                status_code=400,
                detail=f"automation_mode must be one of {sorted(valid)}",
            )
    for key, value in data.items():
        setattr(policy, key, value)
    await db.flush()
    return policy


@router.post(
    "/stores/{store_id}/agent/run", response_model=AgentRunResponse
)
async def run_agent(
    store_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """
    AI 에이전트 1회 실행 — at_risk 고객에게 예산 한도 내 복귀 도장 발급.
    (Premium 기능. 실제 운영에선 스케줄러가 주기 호출.)
    """
    agent = AgentService(db, redis_client)
    try:
        summary = await agent.run_pass(store_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return AgentRunResponse(**summary)


@router.get(
    "/stores/{store_id}/agent/report", response_model=AgentReportResponse
)
async def agent_report(
    store_id: uuid.UUID,
    period: str | None = None,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """
    월간 AI 에이전트 성과 리포트 — 처치군 vs 대조군 재방문율로 증분 효과 산출.
    period 미지정 시 이번 달(YYYY-MM).
    """
    agent = AgentService(db, redis_client)
    try:
        report = await agent.performance_report(store_id, period)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return AgentReportResponse(**report)


@router.post("/agent/run-all")
async def run_all_agents(
    redis_client=Depends(get_redis),
):
    """automation_mode=auto 인 모든 매장에 대해 에이전트 1회 일괄 실행 (수동 트리거)."""
    return await run_all_auto_stores(redis_client)
