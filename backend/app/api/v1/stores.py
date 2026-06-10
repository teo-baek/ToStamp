"""
Stores API — 매장 CRUD, 대시보드, 쿠폰 이미지 업로드.
"""

import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.store import Store
from app.redis_client import get_redis
from app.schemas.store import (
    StoreCreate,
    StoreDashboard,
    StoreResponse,
    StoreUpdate,
)
from app.services.stamp_service import StampService

router = APIRouter(prefix="/stores", tags=["stores"])


@router.get("/", response_model=list[StoreResponse])
async def list_stores(
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
):
    """매장 목록 (상권 연합 멤버 선택 등 admin용)."""
    result = await db.execute(
        select(Store).order_by(Store.created_at.desc()).limit(limit)
    )
    return list(result.scalars().all())


@router.post("/", response_model=StoreResponse, status_code=201)
async def create_store(
    request: StoreCreate,
    db: AsyncSession = Depends(get_db),
):
    """매장 등록."""
    store = Store(
        owner_phone=request.owner_phone,
        store_name=request.store_name,
        stamp_goal=request.stamp_goal,
        reward_price_krw=request.reward_price_krw,
        reward_description=request.reward_description,
    )
    db.add(store)
    await db.flush()
    return store


@router.get("/{store_id}", response_model=StoreResponse)
async def get_store(
    store_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """매장 정보 조회."""
    result = await db.execute(select(Store).where(Store.id == store_id))
    store = result.scalar_one_or_none()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")
    return store


@router.patch("/{store_id}", response_model=StoreResponse)
async def update_store(
    store_id: uuid.UUID,
    request: StoreUpdate,
    db: AsyncSession = Depends(get_db),
):
    """매장 정보 수정."""
    result = await db.execute(select(Store).where(Store.id == store_id))
    store = result.scalar_one_or_none()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    update_data = request.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(store, key, value)

    await db.flush()
    return store


_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
_IMAGE_MAX_BYTES = 5 * 1024 * 1024  # 5MB
_STATIC_DIR = Path(__file__).resolve().parents[3] / "static"


@router.post("/{store_id}/image")
async def upload_store_image(
    store_id: uuid.UUID,
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
):
    """매장 쿠폰 이미지 업로드 → /static 저장 후 coupon_image_url 갱신."""
    result = await db.execute(select(Store).where(Store.id == store_id))
    store = result.scalar_one_or_none()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    ext = _IMAGE_TYPES.get(file.content_type or "")
    if ext is None:
        raise HTTPException(
            status_code=400,
            detail=f"지원하지 않는 이미지 형식입니다. 허용: {sorted(_IMAGE_TYPES)}",
        )

    data = await file.read()
    if len(data) > _IMAGE_MAX_BYTES:
        raise HTTPException(status_code=413, detail="이미지는 5MB 이하여야 합니다")

    image_dir = _STATIC_DIR / "store_images"
    image_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{store.id.hex}{ext}"
    (image_dir / filename).write_bytes(data)

    store.coupon_image_url = f"/static/store_images/{filename}"
    await db.flush()
    return {"coupon_image_url": store.coupon_image_url}


@router.get("/{store_id}/dashboard", response_model=StoreDashboard)
async def get_dashboard(
    store_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    redis_client=Depends(get_redis),
):
    """사장님 대시보드 — 4개 핵심 지표."""
    stamp_service = StampService(db, redis_client)
    stats = await stamp_service.get_store_dashboard(store_id)
    return StoreDashboard(**stats)
