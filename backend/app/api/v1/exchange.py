"""
Exchange API — ToStamp 머니 충전/조회, 매장 도장 직접 구매, C2C 거래소.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.exchange import (
    BuyStoreStampsRequest,
    CreateListingRequest,
    ListingResponse,
    MoneyBalanceResponse,
    ReserveStatusResponse,
    TopupRequest,
)
from app.services.exchange_service import ExchangeError, ExchangeService

router = APIRouter(prefix="/exchange", tags=["exchange"])


def _svc(db: AsyncSession) -> ExchangeService:
    return ExchangeService(db)


@router.post("/money/{guest_id}/topup", response_model=MoneyBalanceResponse)
async def topup(
    guest_id: uuid.UUID,
    request: TopupRequest,
    db: AsyncSession = Depends(get_db),
):
    """ToStamp 머니 현금 충전 (MVP: 결제 PG 생략, 금액 즉시 반영)."""
    try:
        acc = await _svc(db).topup(guest_id, request.amount_krw)
    except ExchangeError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return MoneyBalanceResponse(balance_krw=acc.balance_krw)


@router.get("/money/{guest_id}", response_model=MoneyBalanceResponse)
async def get_balance(
    guest_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """머니 잔액 조회."""
    try:
        balance = await _svc(db).get_balance(guest_id)
    except ExchangeError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return MoneyBalanceResponse(balance_krw=balance)


@router.post("/{guest_id}/buy-stamps")
async def buy_store_stamps(
    guest_id: uuid.UUID,
    request: BuyStoreStampsRequest,
    db: AsyncSession = Depends(get_db),
):
    """매장 도장 직접 구매 (머니로 결제 → 매장 정산 대기)."""
    try:
        return await _svc(db).buy_store_stamps(
            guest_id, request.store_id, request.qty
        )
    except ExchangeError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{guest_id}/listings", response_model=ListingResponse)
async def create_listing(
    guest_id: uuid.UUID,
    request: CreateListingRequest,
    db: AsyncSession = Depends(get_db),
):
    """C2C 매물 등록 (도장 에스크로 잠금, 호가 ≤ 액면가 합)."""
    try:
        return await _svc(db).create_listing(
            guest_id, request.store_id, request.qty, request.ask_price_krw
        )
    except ExchangeError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/listings", response_model=list[ListingResponse])
async def list_open(
    store_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_db),
):
    """열린 매물 목록 (store_id로 필터 가능)."""
    return await _svc(db).list_open(store_id)


@router.post("/{guest_id}/listings/{listing_id}/buy")
async def buy_listing(
    guest_id: uuid.UUID,
    listing_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """C2C 매물 구매 (머니 결제 → 도장 이전)."""
    try:
        return await _svc(db).buy_listing(guest_id, listing_id)
    except ExchangeError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{guest_id}/listings/{listing_id}")
async def cancel_listing(
    guest_id: uuid.UUID,
    listing_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """매물 취소 (에스크로 도장 환원)."""
    try:
        await _svc(db).cancel_listing(guest_id, listing_id)
    except ExchangeError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"status": "cancelled"}


@router.get("/reserve", response_model=ReserveStatusResponse)
async def reserve_status(db: AsyncSession = Depends(get_db)):
    """솔벤시/발행잔액 모니터링 (운영·규제용)."""
    status = await _svc(db).reserve_status()
    return ReserveStatusResponse(**status)
