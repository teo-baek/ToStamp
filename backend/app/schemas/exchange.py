"""
Exchange schemas — 머니/거래소 요청·응답.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class TopupRequest(BaseModel):
    amount_krw: int = Field(..., gt=0, le=1_000_000, examples=[10000])


class MoneyBalanceResponse(BaseModel):
    balance_krw: int


class BuyStoreStampsRequest(BaseModel):
    store_id: uuid.UUID
    qty: int = Field(..., gt=0, le=100)


class CreateListingRequest(BaseModel):
    store_id: uuid.UUID
    qty: int = Field(..., gt=0, le=100)
    ask_price_krw: int = Field(..., gt=0)


class ListingResponse(BaseModel):
    id: uuid.UUID
    seller_customer_id: uuid.UUID
    store_id: uuid.UUID
    stamp_qty: int
    unit_face_value_krw: int
    ask_price_krw: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ReserveStatusResponse(BaseModel):
    total_cash_in_krw: int
    customer_money_balance_krw: int
    store_payable_open_krw: int
    solvent: bool
    issuance_outstanding_krw: int
    issuance_limit_krw: int
    issuance_alert_krw: int
    issuance_alert_triggered: bool
