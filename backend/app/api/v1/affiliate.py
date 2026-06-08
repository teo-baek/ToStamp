"""
Affiliate API — 상권 연합, 공동 적립 이벤트, 이웃 쿠폰 교차 노출 (무현금 상생망).
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.affiliate import (
    AddMemberRequest,
    CreateCrossPromoRequest,
    CreateEventRequest,
    CreateGroupRequest,
    CrossPromoResponse,
    EventProgressResponse,
    EventResponse,
    GroupResponse,
    StoreBrief,
)
from app.services.affiliate_service import AffiliateError, AffiliateService

router = APIRouter(prefix="/affiliate", tags=["affiliate"])


def _svc(db: AsyncSession) -> AffiliateService:
    return AffiliateService(db)


@router.post("/groups", response_model=GroupResponse, status_code=201)
async def create_group(
    request: CreateGroupRequest, db: AsyncSession = Depends(get_db)
):
    """상권 연합 그룹 생성."""
    return await _svc(db).create_group(request.name)


@router.post("/groups/{group_id}/members", status_code=201)
async def add_member(
    group_id: uuid.UUID,
    request: AddMemberRequest,
    db: AsyncSession = Depends(get_db),
):
    """그룹에 가맹점 추가."""
    try:
        m = await _svc(db).add_member(group_id, request.store_id)
    except AffiliateError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"group_id": str(group_id), "store_id": str(m.store_id)}


@router.get("/groups/{group_id}/members", response_model=list[StoreBrief])
async def list_members(group_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """그룹 멤버 매장 목록."""
    return await _svc(db).list_members(group_id)


@router.post(
    "/groups/{group_id}/events", response_model=EventResponse, status_code=201
)
async def create_event(
    group_id: uuid.UUID,
    request: CreateEventRequest,
    db: AsyncSession = Depends(get_db),
):
    """공동 적립 이벤트 생성."""
    try:
        return await _svc(db).create_event(
            group_id=group_id,
            title=request.title,
            required_visits=request.required_visits,
            reward_store_id=request.reward_store_id,
            start_at=request.start_at,
            end_at=request.end_at,
            reward_description=request.reward_description,
        )
    except AffiliateError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/events/{event_id}/progress/{guest_id}",
    response_model=EventProgressResponse,
)
async def event_progress(
    event_id: uuid.UUID,
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """고객의 이벤트 진행 상황."""
    try:
        return await _svc(db).event_progress(event_id, guest_id)
    except AffiliateError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/events/{event_id}/claim/{guest_id}")
async def claim_event(
    event_id: uuid.UUID,
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """이벤트 완성 보너스 수령 (보상 매장이 자기 원가로 제공)."""
    try:
        return await _svc(db).claim_event(event_id, guest_id)
    except AffiliateError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/groups/{group_id}/cross-promos", status_code=201)
async def create_cross_promo(
    group_id: uuid.UUID,
    request: CreateCrossPromoRequest,
    db: AsyncSession = Depends(get_db),
):
    """이웃 쿠폰 교차 노출 프로모 생성."""
    try:
        promo = await _svc(db).create_cross_promo(
            group_id, request.store_id, request.title, request.bonus_stamps
        )
    except AffiliateError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"promo_id": str(promo.id), "store_id": str(promo.store_id)}


@router.get(
    "/cross-promos/{guest_id}", response_model=list[CrossPromoResponse]
)
async def cross_promos_for(
    guest_id: uuid.UUID, db: AsyncSession = Depends(get_db)
):
    """고객에게 노출할 이웃 매장 웰컴 프로모 (아직 방문 안 한 멤버 매장)."""
    try:
        return await _svc(db).cross_promos_for(guest_id)
    except AffiliateError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/cross-promos/{promo_id}/claim/{guest_id}")
async def claim_cross_promo(
    promo_id: uuid.UUID,
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """이웃 프로모 수령 (그 매장이 자기 원가로 도장 선지급)."""
    try:
        return await _svc(db).claim_cross_promo(promo_id, guest_id)
    except AffiliateError as e:
        raise HTTPException(status_code=400, detail=str(e))
