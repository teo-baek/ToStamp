"""
Exchange Service — 도장 거래소 + ToStamp 머니 엔진.

핵심 불변식 (솔벤시):
  Σ(고객 머니 잔액) + Σ(미정산 매장 채무) == Σ(현금 충전 총액)
머니는 충전/거래로만 생성, 무상 발행 없음, 외부 인출 없음.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.marketplace import ListingStatus, MarketplaceListing
from app.models.money import (
    MoneyAccount,
    MoneyTransaction,
    MoneyTxnType,
    PayableStatus,
    StorePayable,
)
from app.models.stamp_card import StampCard
from app.models.store import Store
from app.services.stamp_helpers import add_stamps, customer_by_guest

# 선불전자지급수단 면제 한도 (전자금융거래법 2024.9.15) — 머니 발행잔액 모니터링.
ISSUANCE_LIMIT_KRW = 3_000_000_000     # 30억
ISSUANCE_ALERT_KRW = 2_400_000_000     # 24억 (80%)


class ExchangeError(ValueError):
    """거래소 도메인 오류 (400 매핑)."""


class ExchangeService:
    def __init__(self, db: AsyncSession):
        self.db = db

    # ── 고객/계정 헬퍼 ────────────────────────────────
    async def _customer_by_guest(self, guest_id: uuid.UUID) -> Customer:
        return await customer_by_guest(self.db, guest_id, ExchangeError)

    async def get_or_create_account(self, customer_id: uuid.UUID) -> MoneyAccount:
        acc = (
            await self.db.execute(
                select(MoneyAccount).where(
                    MoneyAccount.customer_id == customer_id
                )
            )
        ).scalar_one_or_none()
        if acc is None:
            acc = MoneyAccount(customer_id=customer_id, balance_krw=0)
            self.db.add(acc)
            await self.db.flush()
        return acc

    async def _move_money(
        self,
        account: MoneyAccount,
        amount: int,
        txn_type: MoneyTxnType,
        ref_type: str | None = None,
        ref_id: uuid.UUID | None = None,
    ) -> None:
        """잔액 변동 + 원장 기록. amount 부호 있음. 음수 잔액 금지."""
        new_balance = account.balance_krw + amount
        if new_balance < 0:
            raise ExchangeError("머니 잔액이 부족합니다")
        account.balance_krw = new_balance
        self.db.add(
            MoneyTransaction(
                account_id=account.id,
                txn_type=txn_type.value,
                amount_krw=amount,
                balance_after=new_balance,
                ref_type=ref_type,
                ref_id=ref_id,
            )
        )

    # ── 충전 ─────────────────────────────────────────
    async def topup(self, guest_id: uuid.UUID, amount_krw: int) -> MoneyAccount:
        if amount_krw <= 0:
            raise ExchangeError("충전 금액은 0보다 커야 합니다")
        customer = await self._customer_by_guest(guest_id)
        acc = await self.get_or_create_account(customer.id)
        await self._move_money(acc, amount_krw, MoneyTxnType.TOPUP, "topup")
        await self.db.flush()
        return acc

    async def get_balance(self, guest_id: uuid.UUID) -> int:
        customer = await self._customer_by_guest(guest_id)
        acc = await self.get_or_create_account(customer.id)
        return acc.balance_krw

    # ── 도장 적립 헬퍼 (매장 전용, overflow 시 신규 카드+쿠폰) ──
    async def _add_stamps(
        self, customer_id: uuid.UUID, store: Store, qty: int
    ) -> int:
        return await add_stamps(self.db, customer_id, store, qty)

    # ── 매장 도장 직접 구매 (경로①: 고객 자금 → 매장 채무) ──
    async def buy_store_stamps(
        self, guest_id: uuid.UUID, store_id: uuid.UUID, qty: int
    ) -> dict:
        if qty <= 0:
            raise ExchangeError("수량은 1 이상이어야 합니다")
        customer = await self._customer_by_guest(guest_id)
        store = (
            await self.db.execute(select(Store).where(Store.id == store_id))
        ).scalar_one_or_none()
        if store is None:
            raise ExchangeError("Store not found")

        face = store.reward_price_krw // store.stamp_goal
        cost = face * qty
        acc = await self.get_or_create_account(customer.id)
        # 머니 차감 (현금) → 매장 채무로 이동 (솔벤시 보존)
        await self._move_money(
            acc, -cost, MoneyTxnType.BUY_STORE_STAMP, "store_purchase", store_id
        )
        self.db.add(
            StorePayable(store_id=store_id, amount_krw=cost, source="direct_purchase")
        )
        coupons = await self._add_stamps(customer.id, store, qty)
        await self.db.flush()
        return {
            "store_id": str(store_id),
            "qty": qty,
            "cost_krw": cost,
            "balance_krw": acc.balance_krw,
            "coupons_created": coupons,
        }

    # ── C2C 매물 등록 (도장 에스크로) ──
    async def create_listing(
        self, guest_id: uuid.UUID, store_id: uuid.UUID, qty: int, ask_price_krw: int
    ) -> MarketplaceListing:
        if qty <= 0 or ask_price_krw <= 0:
            raise ExchangeError("수량/호가는 0보다 커야 합니다")
        seller = await self._customer_by_guest(guest_id)
        store = (
            await self.db.execute(select(Store).where(Store.id == store_id))
        ).scalar_one_or_none()
        if store is None:
            raise ExchangeError("Store not found")
        face = store.reward_price_krw // store.stamp_goal
        if ask_price_krw > face * qty:
            raise ExchangeError(
                f"호가는 액면가 합({face * qty}원) 이하여야 합니다"
            )

        # 판매자 활성 카드에서 qty 도장 에스크로 (차감)
        card = (
            await self.db.execute(
                select(StampCard).where(
                    StampCard.customer_id == seller.id,
                    StampCard.store_id == store_id,
                    StampCard.is_completed == False,  # noqa: E712
                )
            )
        ).scalar_one_or_none()
        if card is None or card.current_stamps < qty:
            raise ExchangeError("판매할 도장이 부족합니다")
        card.current_stamps -= qty

        listing = MarketplaceListing(
            seller_customer_id=seller.id,
            store_id=store_id,
            stamp_qty=qty,
            unit_face_value_krw=face,
            ask_price_krw=ask_price_krw,
            status=ListingStatus.OPEN.value,
        )
        self.db.add(listing)
        await self.db.flush()
        return listing

    async def list_open(
        self, store_id: uuid.UUID | None = None
    ) -> list[MarketplaceListing]:
        stmt = select(MarketplaceListing).where(
            MarketplaceListing.status == ListingStatus.OPEN.value
        )
        if store_id is not None:
            stmt = stmt.where(MarketplaceListing.store_id == store_id)
        stmt = stmt.order_by(MarketplaceListing.created_at.desc())
        return list((await self.db.execute(stmt)).scalars().all())

    async def cancel_listing(
        self, guest_id: uuid.UUID, listing_id: uuid.UUID
    ) -> None:
        seller = await self._customer_by_guest(guest_id)
        listing = await self._locked_listing(listing_id)
        if listing.seller_customer_id != seller.id:
            raise ExchangeError("본인 매물만 취소할 수 있습니다")
        if listing.status != ListingStatus.OPEN.value:
            raise ExchangeError("이미 처리된 매물입니다")
        store = (
            await self.db.execute(
                select(Store).where(Store.id == listing.store_id)
            )
        ).scalar_one()
        await self._add_stamps(seller.id, store, listing.stamp_qty)  # 에스크로 환원
        listing.status = ListingStatus.CANCELLED.value
        await self.db.flush()

    async def _locked_listing(self, listing_id: uuid.UUID) -> MarketplaceListing:
        listing = (
            await self.db.execute(
                select(MarketplaceListing)
                .where(MarketplaceListing.id == listing_id)
                .with_for_update()
            )
        ).scalar_one_or_none()
        if listing is None:
            raise ExchangeError("Listing not found")
        return listing

    async def buy_listing(
        self, guest_id: uuid.UUID, listing_id: uuid.UUID
    ) -> dict:
        buyer = await self._customer_by_guest(guest_id)
        listing = await self._locked_listing(listing_id)
        if listing.status != ListingStatus.OPEN.value:
            raise ExchangeError("이미 판매되었거나 취소된 매물입니다")
        if listing.seller_customer_id == buyer.id:
            raise ExchangeError("본인 매물은 구매할 수 없습니다")  # 자전거래 차단

        store = (
            await self.db.execute(
                select(Store).where(Store.id == listing.store_id)
            )
        ).scalar_one()

        buyer_acc = await self.get_or_create_account(buyer.id)
        seller_acc = await self.get_or_create_account(listing.seller_customer_id)

        # 머니 이동: 구매자 -ask, 판매자 +ask (순합 0)
        await self._move_money(
            buyer_acc, -listing.ask_price_krw, MoneyTxnType.TRADE_BUY,
            "listing", listing.id,
        )
        await self._move_money(
            seller_acc, listing.ask_price_krw, MoneyTxnType.TRADE_SELL,
            "listing", listing.id,
        )
        # 도장 이전: 구매자 카드에 +qty (에스크로에서)
        coupons = await self._add_stamps(buyer.id, store, listing.stamp_qty)

        listing.status = ListingStatus.SOLD.value
        listing.buyer_customer_id = buyer.id
        listing.sold_at = datetime.now(timezone.utc)
        await self.db.flush()
        return {
            "listing_id": str(listing.id),
            "paid_krw": listing.ask_price_krw,
            "stamp_qty": listing.stamp_qty,
            "buyer_balance_krw": buyer_acc.balance_krw,
            "coupons_created": coupons,
        }

    # ── 솔벤시/규제 모니터링 ──────────────────────────
    async def reserve_status(self) -> dict:
        total_topup = (
            await self.db.execute(
                select(func.coalesce(func.sum(MoneyTransaction.amount_krw), 0))
                .where(MoneyTransaction.txn_type == MoneyTxnType.TOPUP.value)
            )
        ).scalar() or 0
        customer_balances = (
            await self.db.execute(
                select(func.coalesce(func.sum(MoneyAccount.balance_krw), 0))
            )
        ).scalar() or 0
        open_payables = (
            await self.db.execute(
                select(func.coalesce(func.sum(StorePayable.amount_krw), 0))
                .where(StorePayable.status == PayableStatus.OPEN.value)
            )
        ).scalar() or 0

        # 발행잔액 = 미사용 머니(고객 잔액). 매장 채무는 정산 대기 현금.
        outstanding = customer_balances
        solvent = (customer_balances + open_payables) == total_topup
        return {
            "total_cash_in_krw": int(total_topup),
            "customer_money_balance_krw": int(customer_balances),
            "store_payable_open_krw": int(open_payables),
            "solvent": bool(solvent),
            "issuance_outstanding_krw": int(outstanding),
            "issuance_limit_krw": ISSUANCE_LIMIT_KRW,
            "issuance_alert_krw": ISSUANCE_ALERT_KRW,
            "issuance_alert_triggered": outstanding >= ISSUANCE_ALERT_KRW,
        }
