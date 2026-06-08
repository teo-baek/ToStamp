"""
Store schemas — 매장 관련 요청/응답 스키마.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field, computed_field, model_validator


class StoreCreate(BaseModel):
    """매장 생성 요청."""
    owner_phone: str = Field(..., max_length=20, examples=["010-1234-5678"])
    store_name: str = Field(..., max_length=100, examples=["모닝 커피 · 강남점"])
    stamp_goal: int = Field(default=10, ge=3, le=30)
    reward_price_krw: int = Field(
        default=5000, ge=0,
        description="보상의 원화 가격. stamp_goal으로 나누어떨어져야 함.",
    )
    reward_description: str = Field(
        default="무료 음료 1잔", max_length=200
    )

    @model_validator(mode="after")
    def _reward_price_divisible(self) -> "StoreCreate":
        # 도장 1개 액면가가 정수 원이 되도록 강제 → 가치 누수/반올림 방지.
        if self.reward_price_krw % self.stamp_goal != 0:
            raise ValueError(
                "reward_price_krw must be divisible by stamp_goal "
                f"({self.reward_price_krw} % {self.stamp_goal} != 0)"
            )
        return self


class StoreUpdate(BaseModel):
    """매장 수정 요청."""
    store_name: str | None = Field(None, max_length=100)
    stamp_goal: int | None = Field(None, ge=3, le=30)
    reward_price_krw: int | None = Field(None, ge=0)
    reward_description: str | None = Field(None, max_length=200)
    coupon_image_url: str | None = None


class StoreResponse(BaseModel):
    """매장 응답."""
    id: uuid.UUID
    owner_phone: str
    store_name: str
    stamp_goal: int
    reward_price_krw: int
    reward_description: str
    coupon_image_url: str | None
    created_at: datetime

    model_config = {"from_attributes": True}

    @computed_field(description="도장 1개 액면가(원) = reward_price_krw // stamp_goal")
    @property
    def face_value_krw(self) -> int:
        return (
            self.reward_price_krw // self.stamp_goal
            if self.stamp_goal else 0
        )


class StoreDashboard(BaseModel):
    """사장님 대시보드 지표."""
    today_stamps: int = Field(description="오늘 적립 수")
    new_customers: int = Field(description="신규 유입 수")
    returning_customers: int = Field(description="단골 재방문 수")
    near_reward_customers: int = Field(description="혜택 임박 고객 수")
