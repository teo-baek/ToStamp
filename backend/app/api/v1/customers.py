"""
Customers API — 고객 정보 조회, FCM 토큰 업데이트.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.customer import Customer
from app.schemas.customer import CustomerResponse

router = APIRouter(prefix="/customers", tags=["customers"])


@router.get("/{guest_id}", response_model=CustomerResponse)
async def get_customer(
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """고객 정보 조회 (guest_id 기반)."""
    result = await db.execute(
        select(Customer).where(Customer.guest_id == guest_id)
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer


@router.patch("/{guest_id}/fcm-token")
async def update_fcm_token(
    guest_id: uuid.UUID,
    fcm_token: str,
    db: AsyncSession = Depends(get_db),
):
    """FCM 토큰 업데이트 (푸시 알림용)."""
    result = await db.execute(
        select(Customer).where(Customer.guest_id == guest_id)
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    customer.fcm_token = fcm_token
    await db.flush()

    return {"status": "success"}
