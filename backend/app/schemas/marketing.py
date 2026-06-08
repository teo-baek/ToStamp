"""
Marketing schemas — 세그먼트·AI 에이전트 관련 요청/응답.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class CustomerProfileResponse(BaseModel):
    """세그먼트/단골 리스트용 고객 프로필."""
    customer_id: uuid.UUID
    display_name: str
    visits: int
    max_stamps: int
    last_visit: datetime | None
    days_since_last: int
    segments: list[str]


class SegmentCountsResponse(BaseModel):
    """세그먼트별 고객 수."""
    total: int = 0
    new: int = 0
    loyal: int = 0
    at_risk: int = 0
    near_reward: int = 0
    churned: int = 0


class AgentPolicyResponse(BaseModel):
    """AI 에이전트 정책."""
    store_id: uuid.UUID
    budget_stamps_max: int
    budget_consumed: int
    budget_period: str | None
    automation_mode: str
    at_risk_days: int

    model_config = {"from_attributes": True}


class AgentPolicyUpdate(BaseModel):
    """AI 에이전트 정책 수정."""
    budget_stamps_max: int | None = Field(None, ge=0, le=10000)
    automation_mode: str | None = Field(
        None, description="auto | approval | off"
    )
    at_risk_days: int | None = Field(None, ge=3, le=90)


class AgentRunResponse(BaseModel):
    """에이전트 1회 실행 요약."""
    status: str
    targeted: int = 0
    issued: int = 0
    holdout: int = 0
    skipped_recent: int = 0
    budget_max: int = 0
    budget_consumed: int = 0
    budget_left: int = 0


class AgentReportResponse(BaseModel):
    """월간 성과 리포트 (홀드아웃 기반 증분 효과)."""
    period: str
    treated: int
    treated_returned: int
    treated_return_rate: float
    holdout: int
    holdout_returned: int
    holdout_return_rate: float
    incremental_lift: float
    incremental_returns: int
    avg_ticket_krw: int
    est_incremental_revenue_krw: int
    stamps_spent: int
