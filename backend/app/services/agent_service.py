"""
Agent Service — 자율주행 AI 마케팅 에이전트의 실행 엔진 (Premium).

사장님이 설정한 예산(budget_stamps_max) 한도 내에서만 at_risk 고객에게
'복귀 응원 도장'을 자동 발급한다. 증분 효과 측정을 위해 대상의 약 10%는
무처치 대조군(holdout)으로 남긴다.
"""

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent_policy import AgentPolicy, AutomationMode
from app.models.coupon import Coupon, CouponStatus
from app.models.customer import Customer
from app.models.stamp_card import StampCard
from app.models.store import Store
from app.models.visit import Visit
from app.models.agent_policy import AgentActionLog
from app.schemas.stamp import WSCouponEvent, WSStampEvent
from app.services.segmentation_service import SegmentationService

WS_CHANNEL_PREFIX = "ws:customer:"
CONTACT_COOLDOWN_DAYS = 7
HOLDOUT_BUCKET = 10  # customer_id 해시 % 10 == 0 → 무처치 대조군 (~10%)

# 에이전트가 발급한 도장의 Visit.stamped_by 센티넬.
# 일반 매장 스캔(stamped_by=store_id)과 구분 → '유기적 재방문'만 성과로 집계.
AGENT_ACTOR_ID = uuid.UUID("00000000-0000-0000-0000-0000a6e57aff")


class AgentService:
    """예산 한도형 자율 마케팅 실행."""

    def __init__(self, db: AsyncSession, redis_client=None):
        self.db = db
        self.redis = redis_client

    @staticmethod
    def _is_holdout(customer_id: uuid.UUID) -> bool:
        # 결정론적 holdout: 같은 고객은 항상 같은 군에 속함 → 측정 일관성.
        return (customer_id.int % HOLDOUT_BUCKET) == 0

    @staticmethod
    def _current_period() -> str:
        now = datetime.now(timezone.utc)
        return f"{now.year:04d}-{now.month:02d}"

    async def get_or_create_policy(self, store_id: uuid.UUID) -> AgentPolicy:
        result = await self.db.execute(
            select(AgentPolicy).where(AgentPolicy.store_id == store_id)
        )
        policy = result.scalar_one_or_none()
        if policy is None:
            policy = AgentPolicy(
                store_id=store_id, budget_period=self._current_period()
            )
            self.db.add(policy)
            await self.db.flush()
        # 월이 바뀌면 예산 리셋
        period = self._current_period()
        if policy.budget_period != period:
            policy.budget_period = period
            policy.budget_consumed = 0
            await self.db.flush()
        return policy

    async def _contacted_recently(
        self, store_id: uuid.UUID, customer_id: uuid.UUID
    ) -> bool:
        since = datetime.now(timezone.utc) - timedelta(days=CONTACT_COOLDOWN_DAYS)
        result = await self.db.execute(
            select(func.count(AgentActionLog.id)).where(
                AgentActionLog.store_id == store_id,
                AgentActionLog.target_customer_id == customer_id,
                AgentActionLog.created_at >= since,
            )
        )
        return (result.scalar() or 0) > 0

    async def _issue_comeback_stamp(
        self, customer: Customer, store: Store
    ) -> bool:
        """at_risk 고객에게 무료 복귀 도장 1개 발급. 완성 시 쿠폰 생성."""
        result = await self.db.execute(
            select(StampCard).where(
                StampCard.customer_id == customer.id,
                StampCard.store_id == store.id,
                StampCard.is_completed == False,  # noqa: E712
            )
        )
        card = result.scalar_one_or_none()
        if card is None:
            card = StampCard(
                customer_id=customer.id, store_id=store.id, current_stamps=0
            )
            self.db.add(card)
            await self.db.flush()

        card.current_stamps += 1
        self.db.add(Visit(stamp_card_id=card.id, stamped_by=AGENT_ACTOR_ID))

        is_completed = card.current_stamps >= store.stamp_goal
        coupon = None
        if is_completed:
            card.is_completed = True
            card.completed_at = datetime.now(timezone.utc)
            coupon = Coupon(
                stamp_card_id=card.id,
                status=CouponStatus.AVAILABLE,
                face_value_krw=store.reward_price_krw // store.stamp_goal,
            )
            self.db.add(coupon)
        await self.db.flush()

        # 실시간 알림 (고객 앱이 켜져 있으면 즉시 반영)
        if self.redis is not None:
            await self.redis.publish(
                f"{WS_CHANNEL_PREFIX}{customer.guest_id}",
                WSStampEvent(
                    stamp_card_id=card.id,
                    current_stamps=card.current_stamps,
                    stamp_goal=store.stamp_goal,
                    is_completed=is_completed,
                    store_name=store.store_name,
                ).model_dump_json(),
            )
            if is_completed and coupon is not None:
                await self.redis.publish(
                    f"{WS_CHANNEL_PREFIX}{customer.guest_id}",
                    WSCouponEvent(
                        coupon_id=coupon.id,
                        store_name=store.store_name,
                        reward_description=store.reward_description,
                    ).model_dump_json(),
                )
        return is_completed

    async def run_pass(self, store_id: uuid.UUID) -> dict:
        """
        에이전트 1회 실행: at_risk 고객에게 예산 한도 내에서 복귀 도장 발급.
        반환: 실행 요약 (대상/발급/대조군/잔여 예산).
        """
        store = (
            await self.db.execute(select(Store).where(Store.id == store_id))
        ).scalar_one_or_none()
        if store is None:
            raise ValueError("Store not found")

        policy = await self.get_or_create_policy(store_id)
        if policy.automation_mode == AutomationMode.OFF.value:
            return {"status": "off", "issued": 0, "targeted": 0}

        seg = SegmentationService(self.db)
        targets = await seg.get_segment(store_id, "at_risk")

        issued = 0
        holdout = 0
        skipped_recent = 0
        for profile in targets:
            if policy.budget_consumed >= policy.budget_stamps_max:
                break  # 예산 소진 → 하드 정지
            if await self._contacted_recently(store_id, profile.customer_id):
                skipped_recent += 1
                continue

            is_hold = self._is_holdout(profile.customer_id)
            if is_hold:
                # 대조군: 액션 없이 기록만 (증분 효과 비교용)
                self.db.add(
                    AgentActionLog(
                        store_id=store_id,
                        target_customer_id=profile.customer_id,
                        segment="at_risk",
                        action_type="comeback_stamp",
                        cost_stamps=0,
                        is_holdout=True,
                        detail="holdout (no action)",
                    )
                )
                holdout += 1
                continue

            customer = (
                await self.db.execute(
                    select(Customer).where(Customer.id == profile.customer_id)
                )
            ).scalar_one()
            completed = await self._issue_comeback_stamp(customer, store)
            self.db.add(
                AgentActionLog(
                    store_id=store_id,
                    target_customer_id=profile.customer_id,
                    segment="at_risk",
                    action_type="comeback_stamp",
                    cost_stamps=1,
                    is_holdout=False,
                    detail="completed_coupon" if completed else None,
                )
            )
            policy.budget_consumed += 1
            issued += 1

        await self.db.flush()
        return {
            "status": "ok",
            "targeted": len(targets),
            "issued": issued,
            "holdout": holdout,
            "skipped_recent": skipped_recent,
            "budget_max": policy.budget_stamps_max,
            "budget_consumed": policy.budget_consumed,
            "budget_left": policy.budget_stamps_max - policy.budget_consumed,
        }

    async def _organic_returned_after(
        self, store_id: uuid.UUID, customer_id: uuid.UUID, after: datetime
    ) -> bool:
        """액션 이후 '유기적' 재방문(에이전트 발급 제외) 여부."""
        result = await self.db.execute(
            select(func.count(Visit.id))
            .select_from(Visit)
            .join(StampCard, Visit.stamp_card_id == StampCard.id)
            .where(
                StampCard.store_id == store_id,
                StampCard.customer_id == customer_id,
                Visit.stamped_by != AGENT_ACTOR_ID,
                Visit.stamped_at > after,
            )
        )
        return (result.scalar() or 0) > 0

    async def performance_report(
        self, store_id: uuid.UUID, period: str | None = None
    ) -> dict:
        """
        월간 성과 리포트 — 처치군(treated) vs 대조군(holdout)의 재방문율 차이로
        AI 에이전트의 '증분 효과(incrementality)'를 인과 추정한다.
        """
        period = period or self._current_period()
        store = (
            await self.db.execute(select(Store).where(Store.id == store_id))
        ).scalar_one_or_none()
        if store is None:
            raise ValueError("Store not found")
        avg_ticket = store.reward_price_krw // max(store.stamp_goal, 1)

        logs = (
            await self.db.execute(
                select(AgentActionLog).where(
                    AgentActionLog.store_id == store_id,
                    AgentActionLog.action_type == "comeback_stamp",
                )
            )
        ).scalars().all()

        def _in_period(dt: datetime) -> bool:
            if dt is None:
                return False
            aware = dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
            return f"{aware.year:04d}-{aware.month:02d}" == period

        treated = [
            l for l in logs if not l.is_holdout and _in_period(l.created_at)
        ]
        holdout = [
            l for l in logs if l.is_holdout and _in_period(l.created_at)
        ]

        treated_ret = 0
        for l in treated:
            if await self._organic_returned_after(
                store_id, l.target_customer_id, l.created_at
            ):
                treated_ret += 1
        holdout_ret = 0
        for l in holdout:
            if await self._organic_returned_after(
                store_id, l.target_customer_id, l.created_at
            ):
                holdout_ret += 1

        t_rate = treated_ret / len(treated) if treated else 0.0
        h_rate = holdout_ret / len(holdout) if holdout else 0.0
        lift = t_rate - h_rate
        incremental_returns = round(lift * len(treated))
        est_incremental_revenue = max(0, incremental_returns) * avg_ticket

        return {
            "period": period,
            "treated": len(treated),
            "treated_returned": treated_ret,
            "treated_return_rate": round(t_rate, 3),
            "holdout": len(holdout),
            "holdout_returned": holdout_ret,
            "holdout_return_rate": round(h_rate, 3),
            "incremental_lift": round(lift, 3),
            "incremental_returns": incremental_returns,
            "avg_ticket_krw": avg_ticket,
            "est_incremental_revenue_krw": est_incremental_revenue,
            "stamps_spent": len(treated),
        }
