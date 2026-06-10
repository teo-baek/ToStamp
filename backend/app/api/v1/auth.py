"""
Auth API — 게스트 등록, QR 토큰 관리, 카카오 로그인.
"""

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from jose import jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.models.customer import Customer
from app.redis_client import get_redis
from app.schemas.customer import (
    GuestRegisterResponse,
    KakaoLoginRequest,
    KakaoLoginResponse,
    QRRefreshResponse,
)
from app.services.merge_service import MergeService
from app.services.qr_service import QRService

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _create_access_token(customer_id: uuid.UUID) -> str:
    """Create JWT access token."""
    payload = {
        "sub": str(customer_id),
        "exp": datetime.now(timezone.utc)
        + timedelta(minutes=settings.jwt_access_token_expire_minutes),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


@router.post("/guest", response_model=GuestRegisterResponse)
async def register_guest(
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """
    게스트 즉시 등록 — 앱 첫 실행 시 회원가입 없이 UUID 발급.
    바로 QR 토큰도 함께 생성하여 0초 지연 달성.
    """
    guest_id = uuid.uuid4()

    customer = Customer(guest_id=guest_id)
    db.add(customer)
    await db.flush()

    # Generate first QR token immediately
    qr_service = QRService(redis_client)
    qr_token, expires_at = await qr_service.generate_token(guest_id)

    return GuestRegisterResponse(
        customer_id=customer.id,
        guest_id=guest_id,
        qr_token=qr_token,
        qr_expires_at=expires_at,
    )


@router.post("/qr/refresh", response_model=QRRefreshResponse)
async def refresh_qr_token(
    guest_id: uuid.UUID,
    redis_client=Depends(get_redis),
):
    """3분마다 QR 토큰 갱신."""
    qr_service = QRService(redis_client)
    qr_token, expires_at = await qr_service.generate_token(guest_id)

    return QRRefreshResponse(
        qr_token=qr_token,
        qr_expires_at=expires_at,
    )


@router.post("/kakao", response_model=KakaoLoginResponse)
async def kakao_login(
    request: KakaoLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    카카오 로그인 + 계정 병합 (지연된 가입).
    고객이 쿠폰 사용 시점에 호출.
    """
    merge_service = MergeService(db)

    try:
        customer, merged = await merge_service.merge_accounts(
            guest_id=request.guest_id,
            kakao_access_token=request.kakao_access_token,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="카카오 인증 서버 연결 실패",
        )

    access_token = _create_access_token(customer.id)

    return KakaoLoginResponse(
        customer_id=customer.id,
        nickname=customer.nickname,
        merged=merged,
        access_token=access_token,
    )
