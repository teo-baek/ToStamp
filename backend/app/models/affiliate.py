"""
Affiliate models — 무현금 상권 상생망.

상권 연합(가맹점 그룹) + 공동 적립 이벤트 + 이웃 쿠폰 교차 노출.
핵심: 매장 간 현금 이동이 전혀 없다. 각 매장은 '자기 보상을 자기 원가로'만 제공.
→ R1(교차 정산 비대칭) 구조적으로 발생 불가.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AffiliateGroup(Base):
    """상권 연합 그룹 (예: '강남 OO골목')."""

    __tablename__ = "affiliate_groups"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class AffiliateMember(Base):
    """그룹 ↔ 매장 (다대다)."""

    __tablename__ = "affiliate_members"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("affiliate_groups.id"), nullable=False
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint("group_id", "store_id", name="uq_group_store"),
    )


class CoStampEvent(Base):
    """
    상권 공동 적립 이벤트 — 기간 내 N개 이상 멤버 매장 방문 시 보너스 쿠폰.
    보너스는 reward_store가 자기 원가로 제공(상생: 투어가 그 매장에도 손님을 보냄).
    """

    __tablename__ = "co_stamp_events"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("affiliate_groups.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(120))
    required_visits: Mapped[int] = mapped_column(Integer, default=3)
    reward_store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    reward_description: Mapped[str] = mapped_column(
        Text, default="상권 투어 완성 보너스"
    )
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class CoStampClaim(Base):
    """이벤트 보너스 수령 기록 (중복 수령 방지)."""

    __tablename__ = "co_stamp_claims"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    event_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("co_stamp_events.id"), nullable=False
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("customers.id"), nullable=False
    )
    coupon_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        UniqueConstraint("event_id", "customer_id", name="uq_event_customer"),
    )


class CrossPromo(Base):
    """
    이웃 쿠폰 교차 노출 — 멤버 매장의 웰컴 혜택을 (아직 그 매장 고객이 아닌)
    같은 연합 고객에게 앱에서 노출. 클레임 시 그 매장이 자기 원가로 도장 선지급.
    """

    __tablename__ = "cross_promos"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("affiliate_groups.id"), nullable=False
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(120), default="첫 방문 환영 도장")
    bonus_stamps: Mapped[int] = mapped_column(Integer, default=1)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
