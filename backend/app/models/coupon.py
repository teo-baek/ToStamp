"""
Coupon model — 달성 쿠폰 관리.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CouponStatus(str, enum.Enum):
    AVAILABLE = "available"
    USED = "used"
    EXPIRED = "expired"


class Coupon(Base):
    __tablename__ = "coupons"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    stamp_card_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stamp_cards.id"), nullable=False
    )
    # 발급 시점의 도장 1개 액면가 스냅샷(원). 이후 매장이 보상가격을 바꿔도
    # 이미 발급된 쿠폰 가치는 고정.
    face_value_krw: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), default=CouponStatus.AVAILABLE.value
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    stamp_card: Mapped["StampCard"] = relationship(
        "StampCard", back_populates="coupons"
    )
