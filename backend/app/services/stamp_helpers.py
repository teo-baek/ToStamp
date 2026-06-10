"""
공용 도장/고객 헬퍼 — affiliate/exchange 서비스의 중복 로직 단일화.

도장 적립 정책(카드 조회→적립→목표 도달 시 쿠폰 발급)은 반드시 이 모듈
한 곳에서만 수정한다.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.coupon import Coupon, CouponStatus
from app.models.customer import Customer
from app.models.stamp_card import StampCard
from app.models.store import Store


async def customer_by_guest(
    db: AsyncSession,
    guest_id: uuid.UUID,
    not_found_exc: type[Exception],
) -> Customer:
    """guest_id로 고객 조회. 없으면 도메인별 예외를 발생시킨다."""
    c = (
        await db.execute(
            select(Customer).where(Customer.guest_id == guest_id)
        )
    ).scalar_one_or_none()
    if c is None:
        raise not_found_exc("Customer not found")
    return c


async def add_stamps(
    db: AsyncSession,
    customer_id: uuid.UUID,
    store: Store,
    qty: int,
) -> int:
    """
    매장 전용 도장 qty개 적립 (overflow 시 신규 카드 + 쿠폰 발급).
    완성된 쿠폰 수를 반환한다.
    """
    coupons = 0
    remaining = qty
    while remaining > 0:
        card = (
            await db.execute(
                select(StampCard).where(
                    StampCard.customer_id == customer_id,
                    StampCard.store_id == store.id,
                    StampCard.is_completed == False,  # noqa: E712
                )
            )
        ).scalar_one_or_none()
        if card is None:
            card = StampCard(
                customer_id=customer_id, store_id=store.id, current_stamps=0
            )
            db.add(card)
            await db.flush()
        space = store.stamp_goal - card.current_stamps
        add = min(space, remaining)
        card.current_stamps += add
        remaining -= add
        if card.current_stamps >= store.stamp_goal:
            card.is_completed = True
            card.completed_at = datetime.now(timezone.utc)
            db.add(
                Coupon(
                    stamp_card_id=card.id,
                    status=CouponStatus.AVAILABLE,
                    face_value_krw=store.reward_price_krw // store.stamp_goal,
                )
            )
            coupons += 1
        await db.flush()
    return coupons
