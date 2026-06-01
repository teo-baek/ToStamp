"""
Visit model — 방문(도장 적립) 기록.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Visit(Base):
    __tablename__ = "visits"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    stamp_card_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stamp_cards.id"), nullable=False
    )
    stamped_by: Mapped[uuid.UUID] = mapped_column(
        Uuid(), nullable=False, comment="Store owner ID who scanned"
    )
    stamped_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relationships
    stamp_card: Mapped["StampCard"] = relationship(
        "StampCard", back_populates="visits"
    )
