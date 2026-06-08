"""
Segmentation Service — 고객 행동 데이터 기반 세그먼트 분류.

AI 마케팅 에이전트와 사장님 대시보드(단골 TOP, 인사이트)의 공통 데이터 소스.
매장 전용 도장 모델 기준: 한 고객은 StampCard(customer_id, store_id)로 매장에 연결되고,
방문(Visit)은 stamp_card를 통해 집계된다.
"""

import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.stamp_card import StampCard
from app.models.store import Store
from app.models.visit import Visit


# 세그먼트 임계값 (FINAL 확정 G). AgentPolicy로 매장별 오버라이드 가능.
NEW_DAYS = 7
AT_RISK_DAYS = 14
CHURNED_DAYS = 30
LOYAL_MIN_VISITS = 4
NEAR_REWARD_GAP = 2


@dataclass
class CustomerProfile:
    customer_id: uuid.UUID
    guest_id: uuid.UUID
    display_name: str
    visits: int
    max_stamps: int
    last_visit: datetime | None
    first_seen: datetime | None
    days_since_last: int
    segments: list[str]


class SegmentationService:
    """매장 고객을 행동 기반으로 분류."""

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def _display_name(nickname: str | None, guest_id: uuid.UUID) -> str:
        if nickname:
            return nickname
        return f"손님-{str(guest_id)[:4].upper()}"

    @staticmethod
    def _aware(dt: datetime | None) -> datetime | None:
        # SQLite는 naive datetime을 반환 → UTC로 보정 (Postgres는 이미 aware).
        if dt is None:
            return None
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    async def _profiles(self, store_id: uuid.UUID) -> list[CustomerProfile]:
        """매장의 전체 고객 프로필 + 방문 집계."""
        # 매장 도장 목표 (near_reward 판정용)
        goal_row = await self.db.execute(
            select(Store.stamp_goal).where(Store.id == store_id)
        )
        stamp_goal = goal_row.scalar_one_or_none() or 10

        stmt = (
            select(
                Customer.id,
                Customer.guest_id,
                Customer.nickname,
                func.count(Visit.id).label("visits"),
                func.max(Visit.stamped_at).label("last_visit"),
                func.coalesce(func.max(StampCard.current_stamps), 0).label(
                    "max_stamps"
                ),
                func.min(StampCard.created_at).label("first_seen"),
            )
            .select_from(StampCard)
            .join(Customer, Customer.id == StampCard.customer_id)
            .outerjoin(Visit, Visit.stamp_card_id == StampCard.id)
            .where(StampCard.store_id == store_id)
            .group_by(Customer.id, Customer.guest_id, Customer.nickname)
        )
        rows = (await self.db.execute(stmt)).all()

        now = datetime.now(timezone.utc)
        profiles: list[CustomerProfile] = []
        for r in rows:
            last_visit = self._aware(r.last_visit)
            first_seen = self._aware(r.first_seen)
            ref = last_visit or first_seen
            days_since = (now - ref).days if ref else 9999
            first_days = (now - first_seen).days if first_seen else 9999

            segments: list[str] = []
            if first_days <= NEW_DAYS:
                segments.append("new")
            if days_since >= CHURNED_DAYS:
                segments.append("churned")
            elif days_since >= AT_RISK_DAYS and r.visits >= 2:
                segments.append("at_risk")
            if r.visits >= LOYAL_MIN_VISITS and days_since < CHURNED_DAYS:
                segments.append("loyal")
            if 0 < (stamp_goal - r.max_stamps) <= NEAR_REWARD_GAP:
                segments.append("near_reward")

            profiles.append(
                CustomerProfile(
                    customer_id=r.id,
                    guest_id=r.guest_id,
                    display_name=self._display_name(r.nickname, r.guest_id),
                    visits=r.visits,
                    max_stamps=r.max_stamps,
                    last_visit=last_visit,
                    first_seen=first_seen,
                    days_since_last=days_since if ref else 0,
                    segments=segments,
                )
            )
        return profiles

    async def get_segment_counts(self, store_id: uuid.UUID) -> dict[str, int]:
        profiles = await self._profiles(store_id)
        counts = {
            "total": len(profiles),
            "new": 0,
            "loyal": 0,
            "at_risk": 0,
            "near_reward": 0,
            "churned": 0,
        }
        for p in profiles:
            for s in p.segments:
                counts[s] = counts.get(s, 0) + 1
        return counts

    async def get_segment(
        self, store_id: uuid.UUID, segment: str
    ) -> list[CustomerProfile]:
        profiles = await self._profiles(store_id)
        return [p for p in profiles if segment in p.segments]

    async def get_top_customers(
        self, store_id: uuid.UUID, limit: int = 5
    ) -> list[CustomerProfile]:
        profiles = await self._profiles(store_id)
        profiles.sort(key=lambda p: (p.visits, p.max_stamps), reverse=True)
        return profiles[:limit]
