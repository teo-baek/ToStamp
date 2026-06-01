"""
Customer schemas — 고객 관련 요청/응답 스키마.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class GuestRegisterResponse(BaseModel):
    """게스트 등록 응답."""
    customer_id: uuid.UUID
    guest_id: uuid.UUID
    qr_token: str = Field(description="동적 QR에 인코딩할 토큰")
    qr_expires_at: datetime


class QRRefreshResponse(BaseModel):
    """QR 토큰 갱신 응답."""
    qr_token: str
    qr_expires_at: datetime


class KakaoLoginRequest(BaseModel):
    """카카오 로그인 요청."""
    kakao_access_token: str
    guest_id: uuid.UUID


class KakaoLoginResponse(BaseModel):
    """카카오 로그인 + 계정 병합 응답."""
    customer_id: uuid.UUID
    nickname: str | None
    merged: bool = Field(description="기존 게스트 데이터 병합 여부")
    access_token: str = Field(description="JWT 액세스 토큰")


class CustomerResponse(BaseModel):
    """고객 정보 응답."""
    id: uuid.UUID
    guest_id: uuid.UUID
    kakao_id: str | None
    nickname: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
