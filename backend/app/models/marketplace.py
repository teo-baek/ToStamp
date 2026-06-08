"""
Marketplace model — 도장 거래소 C2C 매물.

도장은 '매장 전용'이라 매물의 도장도 발행 매장에서만 사용된다(R1 무관).
가격 상한 = 액면가(투기 차단). 거래 정산은 머니로만.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ListingStatus(str, enum.Enum):
    OPEN = "open"
    SOLD = "sold"
    CANCELLED = "cancelled"


class MarketplaceListing(Base):
    __tablename__ = "marketplace_listings"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    seller_customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("customers.id"), nullable=False
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    stamp_qty: Mapped[int] = mapped_column(Integer)
    unit_face_value_krw: Mapped[int] = mapped_column(Integer)
    ask_price_krw: Mapped[int] = mapped_column(
        Integer, comment="매물 총 호가(머니). 액면가 합 이하 강제."
    )
    status: Mapped[str] = mapped_column(
        String(20), default=ListingStatus.OPEN.value
    )
    buyer_customer_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(), ForeignKey("customers.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    sold_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        # 호가는 양수 & 액면가 합 이하 (투기/시세조작 차단).
        CheckConstraint("ask_price_krw > 0", name="ck_listing_ask_positive"),
        CheckConstraint("stamp_qty > 0", name="ck_listing_qty_positive"),
        CheckConstraint(
            "ask_price_krw <= unit_face_value_krw * stamp_qty",
            name="ck_listing_ask_below_face",
        ),
    )
