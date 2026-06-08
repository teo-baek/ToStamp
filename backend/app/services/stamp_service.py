"""
Stamp Service — 도장 적립 핵심 비즈니스 로직.
스캔 → 적립 → 쿠폰 생성 → 실시간 알림 플로우.
"""

import json
import uuid
from datetime import datetime, timezone

import redis.asyncio as redis
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.coupon import Coupon, CouponStatus
from app.models.customer import Customer
from app.models.stamp_card import StampCard
from app.models.store import Store
from app.models.visit import Visit
from app.schemas.stamp import StampEarnResponse, WSStampEvent, WSCouponEvent
from app.services.qr_service import QRService


class StampService:
    """Core stamp accumulation logic."""

    WS_CHANNEL_PREFIX = "ws:customer:"

    def __init__(self, db: AsyncSession, redis_client: redis.Redis):
        self.db = db
        self.redis = redis_client
        self.qr_service = QRService(redis_client)

    async def earn_stamp(
        self, qr_token: str, store_id: uuid.UUID, stamped_by: uuid.UUID
    ) -> StampEarnResponse:
        """
        Full stamp-earn flow (target: < 1 second total).
        1. Validate QR token
        2. Upsert stamp card
        3. Record visit
        4. Check completion → create coupon
        5. Publish real-time event via Redis
        """
        # 1. Validate AND consume QR token → get guest_id.
        #    consume_token is single-use (atomic GETDEL): a double-tap or
        #    network retry with the same token returns None → no double-earn.
        guest_id = await self.qr_service.consume_token(qr_token)
        if guest_id is None:
            raise ValueError("Invalid or expired QR token")

        # 2. Find customer by guest_id
        result = await self.db.execute(
            select(Customer).where(Customer.guest_id == guest_id)
        )
        customer = result.scalar_one_or_none()
        if customer is None:
            raise ValueError("Customer not found")

        # 3. Find store
        result = await self.db.execute(
            select(Store).where(Store.id == store_id)
        )
        store = result.scalar_one_or_none()
        if store is None:
            raise ValueError("Store not found")

        # 4. Upsert stamp card (find existing active or create new)
        result = await self.db.execute(
            select(StampCard).where(
                StampCard.customer_id == customer.id,
                StampCard.store_id == store_id,
                StampCard.is_completed == False,  # noqa: E712
            )
        )
        stamp_card = result.scalar_one_or_none()

        if stamp_card is None:
            stamp_card = StampCard(
                customer_id=customer.id,
                store_id=store_id,
                current_stamps=0,
            )
            self.db.add(stamp_card)
            await self.db.flush()

        # 5. Increment stamp
        stamp_card.current_stamps += 1

        # 6. Record visit
        visit = Visit(
            stamp_card_id=stamp_card.id,
            stamped_by=stamped_by,
        )
        self.db.add(visit)

        # 7. Check completion
        is_completed = stamp_card.current_stamps >= store.stamp_goal
        if is_completed:
            stamp_card.is_completed = True
            stamp_card.completed_at = datetime.now(timezone.utc)
            # Create coupon — snapshot the per-stamp face value at issuance
            # so later reward-price changes do not alter this coupon's worth.
            coupon = Coupon(
                stamp_card_id=stamp_card.id,
                status=CouponStatus.AVAILABLE,
                face_value_krw=store.reward_price_krw // store.stamp_goal,
            )
            self.db.add(coupon)
            await self.db.flush()

        await self.db.flush()

        # 8. Publish real-time event to Redis Pub/Sub
        stamp_event = WSStampEvent(
            stamp_card_id=stamp_card.id,
            current_stamps=stamp_card.current_stamps,
            stamp_goal=store.stamp_goal,
            is_completed=is_completed,
            store_name=store.store_name,
        )
        await self.redis.publish(
            f"{self.WS_CHANNEL_PREFIX}{guest_id}",
            stamp_event.model_dump_json(),
        )

        # 9. If completed, also publish coupon event
        if is_completed:
            coupon_event = WSCouponEvent(
                coupon_id=coupon.id,
                store_name=store.store_name,
                reward_description=store.reward_description,
            )
            await self.redis.publish(
                f"{self.WS_CHANNEL_PREFIX}{guest_id}",
                coupon_event.model_dump_json(),
            )

        return StampEarnResponse(
            stamp_card_id=stamp_card.id,
            current_stamps=stamp_card.current_stamps,
            stamp_goal=store.stamp_goal,
            is_completed=is_completed,
            store_name=store.store_name,
            reward_description=store.reward_description,
            reward_price_krw=store.reward_price_krw,
            face_value_krw=store.reward_price_krw // store.stamp_goal,
        )

    async def get_customer_cards(
        self, customer_id: uuid.UUID
    ) -> list[dict]:
        """Get all stamp cards for a customer with store info."""
        result = await self.db.execute(
            select(StampCard, Store)
            .join(Store, StampCard.store_id == Store.id)
            .where(StampCard.customer_id == customer_id)
            .order_by(StampCard.created_at.desc())
        )
        cards = []
        for card, store in result.all():
            cards.append({
                "id": card.id,
                "store_id": store.id,
                "store_name": store.store_name,
                "current_stamps": card.current_stamps,
                "stamp_goal": store.stamp_goal,
                "is_completed": card.is_completed,
                "reward_description": store.reward_description,
                "reward_price_krw": store.reward_price_krw,
                "face_value_krw": store.reward_price_krw // store.stamp_goal,
                "coupon_image_url": store.coupon_image_url,
                "created_at": card.created_at,
            })
        return cards

    async def get_store_dashboard(self, store_id: uuid.UUID) -> dict:
        """Get dashboard stats for a store (4 key metrics)."""
        today = datetime.now(timezone.utc).date()

        # Today's stamps
        today_stamps = await self.db.execute(
            select(func.count(Visit.id))
            .join(StampCard, Visit.stamp_card_id == StampCard.id)
            .where(
                StampCard.store_id == store_id,
                func.date(Visit.stamped_at) == today,
            )
        )

        # New customers (first visit today)
        new_customers = await self.db.execute(
            select(func.count(func.distinct(StampCard.customer_id)))
            .where(
                StampCard.store_id == store_id,
                func.date(StampCard.created_at) == today,
            )
        )

        # Returning customers today (had previous visits before today)
        returning = await self.db.execute(
            select(func.count(func.distinct(StampCard.customer_id)))
            .join(Visit, StampCard.id == Visit.stamp_card_id)
            .where(
                StampCard.store_id == store_id,
                func.date(Visit.stamped_at) == today,
                StampCard.created_at < datetime.combine(
                    today, datetime.min.time()
                ).replace(tzinfo=timezone.utc),
            )
        )

        # Get store stamp_goal
        store_result = await self.db.execute(
            select(Store.stamp_goal).where(Store.id == store_id)
        )
        stamp_goal = store_result.scalar_one()

        # Near reward (stamp_goal - 1 or stamp_goal - 2)
        near_reward = await self.db.execute(
            select(func.count(StampCard.id))
            .where(
                StampCard.store_id == store_id,
                StampCard.is_completed == False,  # noqa: E712
                StampCard.current_stamps >= stamp_goal - 2,
            )
        )

        return {
            "today_stamps": today_stamps.scalar() or 0,
            "new_customers": new_customers.scalar() or 0,
            "returning_customers": returning.scalar() or 0,
            "near_reward_customers": near_reward.scalar() or 0,
        }
