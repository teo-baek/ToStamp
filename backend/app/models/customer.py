"""
Customer model — 고객 정보 (게스트 + 정식 계정 통합).
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    guest_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), unique=True, nullable=False
    )
    kakao_id: Mapped[str | None] = mapped_column(
        String(100), unique=True, nullable=True
    )
    nickname: Mapped[str | None] = mapped_column(String(50), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    fcm_token: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relationships
    stamp_cards: Mapped[list["StampCard"]] = relationship(
        "StampCard", back_populates="customer", lazy="selectin"
    )
