"""
Stamp schemas — 도장 적립/쿠폰 관련 요청/응답 스키마.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.coupon import CouponStatus


class StampEarnRequest(BaseModel):
    """도장 적립 요청 (사장님 QR 스캔 시)."""
    qr_token: str = Field(description="고객 QR에서 읽은 토큰")
    store_id: uuid.UUID


class StampEarnResponse(BaseModel):
    """도장 적립 응답."""
    stamp_card_id: uuid.UUID
    current_stamps: int
    stamp_goal: int
    is_completed: bool
    store_name: str
    reward_description: str


class StampCardResponse(BaseModel):
    """스탬프 카드 상세."""
    id: uuid.UUID
    store_id: uuid.UUID
    store_name: str
    current_stamps: int
    stamp_goal: int
    is_completed: bool
    reward_description: str
    coupon_image_url: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class CouponResponse(BaseModel):
    """쿠폰 응답."""
    id: uuid.UUID
    stamp_card_id: uuid.UUID
    store_name: str
    reward_description: str
    status: CouponStatus
    created_at: datetime
    used_at: datetime | None
    expires_at: datetime | None

    model_config = {"from_attributes": True}


class CouponUseRequest(BaseModel):
    """쿠폰 사용 요청."""
    coupon_id: uuid.UUID
    store_id: uuid.UUID


# WebSocket event payloads
class WSStampEvent(BaseModel):
    """WebSocket: 도장 적립 이벤트."""
    event: str = "stamp_earned"
    stamp_card_id: uuid.UUID
    current_stamps: int
    stamp_goal: int
    is_completed: bool
    store_name: str


class WSCouponEvent(BaseModel):
    """WebSocket: 쿠폰 달성 이벤트."""
    event: str = "coupon_earned"
    coupon_id: uuid.UUID
    store_name: str
    reward_description: str
