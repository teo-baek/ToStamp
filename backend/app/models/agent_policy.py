"""
AgentPolicy / AgentActionLog — AI 마케팅 에이전트 정책 및 실행 이력.

사장님(Premium)이 "이달 마케팅용 도장 최대 N개"처럼 예산만 설정하면,
에이전트가 그 한도 내에서만 자동으로 도장 발급/푸시를 실행한다.
"""

import enum
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
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AutomationMode(str, enum.Enum):
    AUTO = "auto"          # 에이전트가 즉시 실행
    APPROVAL = "approval"  # 후보만 큐에 적재 → 사장님 승인 후 실행
    OFF = "off"            # 비활성


class AgentPolicy(Base):
    """매장별 AI 에이전트 예산·자동화 정책. (매장당 1행)"""

    __tablename__ = "agent_policies"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), unique=True, nullable=False
    )
    # 이달 마케팅용으로 발급 허용하는 최대 도장 수 (하드 상한)
    budget_stamps_max: Mapped[int] = mapped_column(Integer, default=50)
    budget_consumed: Mapped[int] = mapped_column(Integer, default=0)
    # 예산 리셋 기준 기간 "YYYY-MM" — 바뀌면 budget_consumed 0으로 리셋
    budget_period: Mapped[str | None] = mapped_column(String(7), nullable=True)
    automation_mode: Mapped[str] = mapped_column(
        String(20), default=AutomationMode.AUTO.value
    )
    # at_risk 판정 기준 미방문 일수 등 (튜닝용)
    at_risk_days: Mapped[int] = mapped_column(Integer, default=14)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class AgentActionLog(Base):
    """에이전트가 수행한 단위 액션 기록 (성과 측정·중복 발송 방지용)."""

    __tablename__ = "agent_action_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    target_customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("customers.id"), nullable=False
    )
    segment: Mapped[str] = mapped_column(String(20))
    action_type: Mapped[str] = mapped_column(
        String(30), comment="comeback_stamp | near_reward_push | ..."
    )
    cost_stamps: Mapped[int] = mapped_column(Integer, default=0)
    # 성과 측정용: holdout 대조군이면 액션을 실행하지 않고 기록만 함
    is_holdout: Mapped[bool] = mapped_column(Boolean, default=False)
    detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
