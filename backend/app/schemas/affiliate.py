"""
Affiliate schemas — 상권 상생망 요청·응답.
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class CreateGroupRequest(BaseModel):
    name: str = Field(..., max_length=100, examples=["강남 OO골목 상권"])


class GroupResponse(BaseModel):
    id: uuid.UUID
    name: str

    model_config = {"from_attributes": True}


class AddMemberRequest(BaseModel):
    store_id: uuid.UUID


class StoreBrief(BaseModel):
    id: uuid.UUID
    store_name: str

    model_config = {"from_attributes": True}


class CreateEventRequest(BaseModel):
    title: str = Field(..., max_length=120)
    required_visits: int = Field(3, ge=2, le=20)
    reward_store_id: uuid.UUID
    start_at: datetime
    end_at: datetime
    reward_description: str = "상권 투어 완성 보너스"


class EventResponse(BaseModel):
    id: uuid.UUID
    group_id: uuid.UUID
    title: str
    required_visits: int
    reward_store_id: uuid.UUID
    reward_description: str
    start_at: datetime
    end_at: datetime
    active: bool

    model_config = {"from_attributes": True}


class EventProgressResponse(BaseModel):
    event_id: str
    title: str
    visited: int
    required: int
    eligible: bool
    claimed: bool
    reward_description: str


class CreateCrossPromoRequest(BaseModel):
    store_id: uuid.UUID
    title: str = "첫 방문 환영 도장"
    bonus_stamps: int = Field(1, ge=1, le=5)


class CrossPromoResponse(BaseModel):
    promo_id: str
    store_id: str
    store_name: str
    title: str
    bonus_stamps: int
    reward_description: str
    stamp_goal: int
