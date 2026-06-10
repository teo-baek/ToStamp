"""
Affiliate Service — 무현금 상권 상생망 엔진.

상권 연합, 공동 적립 이벤트(진행/완성), 이웃 쿠폰 교차 노출.
어떤 경로에도 매장 간 현금 이동이 없다 (각 매장이 자기 보상을 자기 원가로).
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.affiliate import (
    AffiliateGroup,
    AffiliateMember,
    CoStampClaim,
    CoStampEvent,
    CrossPromo,
)
from app.models.coupon import Coupon, CouponStatus
from app.models.customer import Customer
from app.models.stamp_card import StampCard
from app.models.store import Store
from app.models.visit import Visit
from app.services.stamp_helpers import add_stamps, customer_by_guest


class AffiliateError(ValueError):
    """상생망 도메인 오류 (400 매핑)."""


class AffiliateService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def _customer_by_guest(self, guest_id: uuid.UUID) -> Customer:
        return await customer_by_guest(self.db, guest_id, AffiliateError)

    async def _member_store_ids(self, group_id: uuid.UUID) -> list[uuid.UUID]:
        rows = await self.db.execute(
            select(AffiliateMember.store_id).where(
                AffiliateMember.group_id == group_id
            )
        )
        return [r[0] for r in rows.all()]

    # ── 그룹/멤버십 ──────────────────────────────────
    async def create_group(self, name: str) -> AffiliateGroup:
        group = AffiliateGroup(name=name)
        self.db.add(group)
        await self.db.flush()
        return group

    async def add_member(
        self, group_id: uuid.UUID, store_id: uuid.UUID
    ) -> AffiliateMember:
        group = (
            await self.db.execute(
                select(AffiliateGroup).where(AffiliateGroup.id == group_id)
            )
        ).scalar_one_or_none()
        if group is None:
            raise AffiliateError("Group not found")
        store = (
            await self.db.execute(select(Store).where(Store.id == store_id))
        ).scalar_one_or_none()
        if store is None:
            raise AffiliateError("Store not found")
        existing = (
            await self.db.execute(
                select(AffiliateMember).where(
                    AffiliateMember.group_id == group_id,
                    AffiliateMember.store_id == store_id,
                )
            )
        ).scalar_one_or_none()
        if existing:
            return existing
        member = AffiliateMember(group_id=group_id, store_id=store_id)
        self.db.add(member)
        await self.db.flush()
        return member

    async def groups_for_store(self, store_id: uuid.UUID) -> list[AffiliateGroup]:
        """매장이 속한 상권 연합 그룹들."""
        group_ids = [
            r[0]
            for r in (
                await self.db.execute(
                    select(AffiliateMember.group_id).where(
                        AffiliateMember.store_id == store_id
                    )
                )
            ).all()
        ]
        if not group_ids:
            return []
        rows = await self.db.execute(
            select(AffiliateGroup).where(AffiliateGroup.id.in_(group_ids))
        )
        return list(rows.scalars().all())

    async def list_members(self, group_id: uuid.UUID) -> list[Store]:
        ids = await self._member_store_ids(group_id)
        if not ids:
            return []
        rows = await self.db.execute(select(Store).where(Store.id.in_(ids)))
        return list(rows.scalars().all())

    # ── 도장/쿠폰 헬퍼 (매장 전용, 자기 원가) ──
    async def _add_stamps(
        self, customer_id: uuid.UUID, store: Store, qty: int
    ) -> int:
        return await add_stamps(self.db, customer_id, store, qty)

    # ── 공동 적립 이벤트 ──────────────────────────────
    async def create_event(
        self,
        group_id: uuid.UUID,
        title: str,
        required_visits: int,
        reward_store_id: uuid.UUID,
        start_at: datetime,
        end_at: datetime,
        reward_description: str = "상권 투어 완성 보너스",
    ) -> CoStampEvent:
        if reward_store_id not in await self._member_store_ids(group_id):
            raise AffiliateError("보상 매장은 그룹 멤버여야 합니다")
        event = CoStampEvent(
            group_id=group_id,
            title=title,
            required_visits=required_visits,
            reward_store_id=reward_store_id,
            reward_description=reward_description,
            start_at=start_at,
            end_at=end_at,
        )
        self.db.add(event)
        await self.db.flush()
        return event

    async def _distinct_visited(
        self, event: CoStampEvent, customer_id: uuid.UUID
    ) -> int:
        """이벤트 기간 내 고객이 방문한 '서로 다른 멤버 매장' 수."""
        member_ids = await self._member_store_ids(event.group_id)
        if not member_ids:
            return 0
        result = await self.db.execute(
            select(func.count(func.distinct(StampCard.store_id)))
            .select_from(Visit)
            .join(StampCard, Visit.stamp_card_id == StampCard.id)
            .where(
                StampCard.customer_id == customer_id,
                StampCard.store_id.in_(member_ids),
                Visit.stamped_at >= event.start_at,
                Visit.stamped_at <= event.end_at,
            )
        )
        return result.scalar() or 0

    async def _get_event(self, event_id: uuid.UUID) -> CoStampEvent:
        ev = (
            await self.db.execute(
                select(CoStampEvent).where(CoStampEvent.id == event_id)
            )
        ).scalar_one_or_none()
        if ev is None:
            raise AffiliateError("Event not found")
        return ev

    async def event_progress(
        self, event_id: uuid.UUID, guest_id: uuid.UUID
    ) -> dict:
        event = await self._get_event(event_id)
        customer = await self._customer_by_guest(guest_id)
        visited = await self._distinct_visited(event, customer.id)
        claimed = (
            await self.db.execute(
                select(CoStampClaim).where(
                    CoStampClaim.event_id == event_id,
                    CoStampClaim.customer_id == customer.id,
                )
            )
        ).scalar_one_or_none() is not None
        return {
            "event_id": str(event_id),
            "title": event.title,
            "visited": visited,
            "required": event.required_visits,
            "eligible": visited >= event.required_visits,
            "claimed": claimed,
            "reward_description": event.reward_description,
        }

    async def claim_event(
        self, event_id: uuid.UUID, guest_id: uuid.UUID
    ) -> dict:
        event = await self._get_event(event_id)
        if not event.active:
            raise AffiliateError("종료된 이벤트입니다")
        customer = await self._customer_by_guest(guest_id)

        already = (
            await self.db.execute(
                select(CoStampClaim).where(
                    CoStampClaim.event_id == event_id,
                    CoStampClaim.customer_id == customer.id,
                )
            )
        ).scalar_one_or_none()
        if already:
            raise AffiliateError("이미 보너스를 받았습니다")

        visited = await self._distinct_visited(event, customer.id)
        if visited < event.required_visits:
            raise AffiliateError(
                f"아직 부족해요 ({visited}/{event.required_visits} 매장)"
            )

        # 보상 매장에서 자기 원가로 보너스 쿠폰 발급 (현금 이동 없음).
        reward_store = (
            await self.db.execute(
                select(Store).where(Store.id == event.reward_store_id)
            )
        ).scalar_one()
        card = StampCard(
            customer_id=customer.id,
            store_id=reward_store.id,
            current_stamps=0,
            is_completed=True,
            completed_at=datetime.now(timezone.utc),
        )
        self.db.add(card)
        await self.db.flush()
        coupon = Coupon(
            stamp_card_id=card.id,
            status=CouponStatus.AVAILABLE,
            face_value_krw=reward_store.reward_price_krw // reward_store.stamp_goal,
        )
        self.db.add(coupon)
        await self.db.flush()
        self.db.add(
            CoStampClaim(
                event_id=event_id, customer_id=customer.id, coupon_id=coupon.id
            )
        )
        await self.db.flush()
        return {
            "event_id": str(event_id),
            "coupon_id": str(coupon.id),
            "reward_store": reward_store.store_name,
            "reward_description": event.reward_description,
        }

    # ── 이웃 쿠폰 교차 노출 ───────────────────────────
    async def create_cross_promo(
        self,
        group_id: uuid.UUID,
        store_id: uuid.UUID,
        title: str = "첫 방문 환영 도장",
        bonus_stamps: int = 1,
    ) -> CrossPromo:
        if store_id not in await self._member_store_ids(group_id):
            raise AffiliateError("프로모 매장은 그룹 멤버여야 합니다")
        promo = CrossPromo(
            group_id=group_id,
            store_id=store_id,
            title=title,
            bonus_stamps=bonus_stamps,
        )
        self.db.add(promo)
        await self.db.flush()
        return promo

    async def cross_promos_for(self, guest_id: uuid.UUID) -> list[dict]:
        """
        고객이 (멤버 매장 중) '아직 방문 안 한' 매장의 활성 프로모만 노출.
        고객이 속한 그룹 = 고객이 방문한 매장이 속한 그룹들.
        """
        customer = await self._customer_by_guest(guest_id)
        # 고객이 카드 가진 매장들
        visited_store_ids = [
            r[0]
            for r in (
                await self.db.execute(
                    select(StampCard.store_id).where(
                        StampCard.customer_id == customer.id
                    )
                )
            ).all()
        ]
        if not visited_store_ids:
            return []
        # 그 매장들이 속한 그룹들
        group_ids = [
            r[0]
            for r in (
                await self.db.execute(
                    select(AffiliateMember.group_id)
                    .where(AffiliateMember.store_id.in_(visited_store_ids))
                    .distinct()
                )
            ).all()
        ]
        if not group_ids:
            return []
        # 그 그룹들의 활성 프로모 중, 아직 방문 안 한 매장 것
        rows = (
            await self.db.execute(
                select(CrossPromo, Store)
                .join(Store, CrossPromo.store_id == Store.id)
                .where(
                    CrossPromo.group_id.in_(group_ids),
                    CrossPromo.active == True,  # noqa: E712
                    CrossPromo.store_id.notin_(visited_store_ids),
                )
            )
        ).all()
        return [
            {
                "promo_id": str(p.id),
                "store_id": str(p.store_id),
                "store_name": s.store_name,
                "title": p.title,
                "bonus_stamps": p.bonus_stamps,
                "reward_description": s.reward_description,
                "stamp_goal": s.stamp_goal,
            }
            for p, s in rows
        ]

    async def claim_cross_promo(
        self, promo_id: uuid.UUID, guest_id: uuid.UUID
    ) -> dict:
        customer = await self._customer_by_guest(guest_id)
        promo = (
            await self.db.execute(
                select(CrossPromo).where(CrossPromo.id == promo_id)
            )
        ).scalar_one_or_none()
        if promo is None or not promo.active:
            raise AffiliateError("유효하지 않은 프로모입니다")
        # 이미 그 매장 고객이면 거부 (웰컴 혜택은 신규만)
        existing = (
            await self.db.execute(
                select(StampCard).where(
                    StampCard.customer_id == customer.id,
                    StampCard.store_id == promo.store_id,
                )
            )
        ).scalar_one_or_none()
        if existing:
            raise AffiliateError("이미 방문한 매장이에요")
        store = (
            await self.db.execute(
                select(Store).where(Store.id == promo.store_id)
            )
        ).scalar_one()
        coupons = await self._add_stamps(customer.id, store, promo.bonus_stamps)
        return {
            "promo_id": str(promo_id),
            "store_name": store.store_name,
            "bonus_stamps": promo.bonus_stamps,
            "coupons_created": coupons,
        }
