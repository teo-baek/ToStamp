"""
Stamps API — 도장 적립, 스탬프 카드 조회, 쿠폰 관리.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.coupon import Coupon, CouponStatus
from app.models.stamp_card import StampCard
from app.models.store import Store
from app.redis_client import get_redis
from app.schemas.stamp import (
    CouponResponse,
    CouponUseRequest,
    StampCardResponse,
    StampEarnRequest,
    StampEarnResponse,
)
from app.services.stamp_service import StampService

router = APIRouter(prefix="/stamps", tags=["stamps"])


@router.post("/earn", response_model=StampEarnResponse)
async def earn_stamp(
    request: StampEarnRequest,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """
    도장 적립 — 사장님이 고객 QR 스캔 시 호출.
    목표: 스캔 → 응답 1초 미만.
    """
    stamp_service = StampService(db, redis_client)
    try:
        result = await stamp_service.earn_stamp(
            qr_token=request.qr_token,
            store_id=request.store_id,
            stamped_by=request.store_id,  # MVP: store_id as stamped_by
        )
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get("/cards/{guest_id}", response_model=list[StampCardResponse])
async def get_stamp_cards(
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """고객의 전체 스탬프 카드 목록."""
    from app.models.customer import Customer

    result = await db.execute(
        select(Customer).where(Customer.guest_id == guest_id)
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    stamp_service = StampService(db, None)
    cards = await stamp_service.get_customer_cards(customer.id)

    return [StampCardResponse(**card) for card in cards]


@router.get("/coupons/{guest_id}", response_model=list[CouponResponse])
async def get_coupons(
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """고객의 쿠폰 목록."""
    from app.models.customer import Customer

    result = await db.execute(
        select(Customer).where(Customer.guest_id == guest_id)
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    result = await db.execute(
        select(Coupon, StampCard, Store)
        .join(StampCard, Coupon.stamp_card_id == StampCard.id)
        .join(Store, StampCard.store_id == Store.id)
        .where(StampCard.customer_id == customer.id)
        .order_by(Coupon.created_at.desc())
    )

    coupons = []
    for coupon, card, store in result.all():
        coupons.append(CouponResponse(
            id=coupon.id,
            stamp_card_id=card.id,
            store_name=store.store_name,
            reward_description=store.reward_description,
            status=coupon.status,
            created_at=coupon.created_at,
            used_at=coupon.used_at,
            expires_at=coupon.expires_at,
        ))
    return coupons


@router.post("/coupons/use")
async def use_coupon(
    request: CouponUseRequest,
    db: AsyncSession = Depends(get_db),
):
    """쿠폰 사용 처리."""
    from datetime import datetime, timezone

    result = await db.execute(
        select(Coupon).where(Coupon.id == request.coupon_id)
    )
    coupon = result.scalar_one_or_none()
    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")

    if coupon.status != CouponStatus.AVAILABLE.value:
        raise HTTPException(
            status_code=400,
            detail=f"Coupon is {coupon.status}",
        )

    coupon.status = CouponStatus.USED.value
    coupon.used_at = datetime.now(timezone.utc)
    await db.flush()

    return {"status": "success", "message": "쿠폰이 사용되었습니다!"}
