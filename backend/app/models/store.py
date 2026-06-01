"""
Store model — 매장 정보.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Store(Base):
    __tablename__ = "stores"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    owner_phone: Mapped[str] = mapped_column(
        String(20), unique=True, nullable=False
    )
    store_name: Mapped[str] = mapped_column(String(100), nullable=False)
    stamp_goal: Mapped[int] = mapped_column(Integer, default=10)
    reward_description: Mapped[str] = mapped_column(
        Text, default="무료 음료 1잔"
    )
    coupon_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    stamp_cards: Mapped[list["StampCard"]] = relationship(
        "StampCard", back_populates="store", lazy="selectin"
    )
