"""
StampCard model — 고객별 매장별 스탬프 카드.
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class StampCard(Base):
    __tablename__ = "stamp_cards"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("customers.id"), nullable=False
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    current_stamps: Mapped[int] = mapped_column(Integer, default=0)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relationships
    customer: Mapped["Customer"] = relationship(
        "Customer", back_populates="stamp_cards"
    )
    store: Mapped["Store"] = relationship(
        "Store", back_populates="stamp_cards"
    )
    visits: Mapped[list["Visit"]] = relationship(
        "Visit", back_populates="stamp_card", lazy="selectin"
    )
    coupons: Mapped[list["Coupon"]] = relationship(
        "Coupon", back_populates="stamp_card", lazy="selectin"
    )
