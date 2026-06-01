"""
Store schemas — 매장 관련 요청/응답 스키마.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class StoreCreate(BaseModel):
    """매장 생성 요청."""
    owner_phone: str = Field(..., max_length=20, examples=["010-1234-5678"])
    store_name: str = Field(..., max_length=100, examples=["모닝 커피 · 강남점"])
    stamp_goal: int = Field(default=10, ge=3, le=30)
    reward_description: str = Field(
        default="무료 음료 1잔", max_length=200
    )


class StoreUpdate(BaseModel):
    """매장 수정 요청."""
    store_name: str | None = Field(None, max_length=100)
    stamp_goal: int | None = Field(None, ge=3, le=30)
    reward_description: str | None = Field(None, max_length=200)
    coupon_image_url: str | None = None


class StoreResponse(BaseModel):
    """매장 응답."""
    id: uuid.UUID
    owner_phone: str
    store_name: str
    stamp_goal: int
    reward_description: str
    coupon_image_url: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class StoreDashboard(BaseModel):
    """사장님 대시보드 지표."""
    today_stamps: int = Field(description="오늘 적립 수")
    new_customers: int = Field(description="신규 유입 수")
    returning_customers: int = Field(description="단골 재방문 수")
    near_reward_customers: int = Field(description="혜택 임박 고객 수")
