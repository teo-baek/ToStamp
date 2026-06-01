"""
Notifications API — FCM 푸시 알림 관리.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.customer import Customer
from app.services.fcm_service import FCMService

router = APIRouter(prefix="/notifications", tags=["notifications"])


class PushNotificationRequest(BaseModel):
    """수동 푸시 알림 발송 요청."""
    guest_id: uuid.UUID
    title: str
    body: str


@router.post("/push")
async def send_push(
    request: PushNotificationRequest,
    db: AsyncSession = Depends(get_db),
):
    """고객에게 푸시 알림 발송."""
    result = await db.execute(
        select(Customer).where(Customer.guest_id == request.guest_id)
    )
    customer = result.scalar_one_or_none()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    if not customer.fcm_token:
        raise HTTPException(status_code=400, detail="No FCM token registered")

    success = await FCMService.send_push(
        fcm_token=customer.fcm_token,
        title=request.title,
        body=request.body,
    )

    if success:
        return {"status": "sent"}
    else:
        raise HTTPException(status_code=502, detail="FCM delivery failed")
