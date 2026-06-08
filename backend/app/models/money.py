"""
Money models — 'ToStamp 머니' (앱 내 전용 현금담보 선불 포인트).

불변식: 머니는 오직 (a) 현금 충전, (b) 현금기반 거래로만 생성된다. 무상 발행 금지.
외부 인출 불가. 솔벤시: Σ(고객 잔액) + Σ(미정산 매장 채무) == Σ(충전 현금).
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


class MoneyTxnType(str, enum.Enum):
    TOPUP = "topup"                    # 현금 충전 (+) — 유일한 신규 발행 경로
    TRADE_SELL = "trade_sell"          # C2C 판매 수령 (+)
    TRADE_BUY = "trade_buy"            # C2C 구매 지불 (-)
    BUY_STORE_STAMP = "buy_store_stamp"  # 매장 도장 직접 구매 지불 (-)


class MoneyAccount(Base):
    """고객별 머니 잔액. (고객당 1행)"""

    __tablename__ = "money_accounts"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("customers.id"), unique=True, nullable=False
    )
    balance_krw: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        CheckConstraint("balance_krw >= 0", name="ck_money_balance_nonneg"),
    )


class MoneyTransaction(Base):
    """머니 변동 원장 (append-only)."""

    __tablename__ = "money_transactions"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    account_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("money_accounts.id"), nullable=False
    )
    txn_type: Mapped[str] = mapped_column(String(30))
    amount_krw: Mapped[int] = mapped_column(
        Integer, comment="부호 있음: 충전/판매 +, 구매 -"
    )
    balance_after: Mapped[int] = mapped_column(Integer)
    ref_type: Mapped[str | None] = mapped_column(String(30), nullable=True)
    ref_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class PayableStatus(str, enum.Enum):
    OPEN = "open"
    SETTLED = "settled"


class StorePayable(Base):
    """
    매장에 지급해야 할 현금 (고객의 매장 도장 직접 구매분).
    고객이 낸 현금이 머니→이 채무로 이동 → 매장 정산 시 소멸. 솔벤시 유지의 핵심.
    """

    __tablename__ = "store_payables"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), primary_key=True, default=uuid.uuid4
    )
    store_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(), ForeignKey("stores.id"), nullable=False
    )
    amount_krw: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(
        String(20), default=PayableStatus.OPEN.value
    )
    source: Mapped[str] = mapped_column(String(30), default="direct_purchase")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    settled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
