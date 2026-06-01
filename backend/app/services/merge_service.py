"""
Merge Service — 게스트 계정 → 카카오 로그인 계정 병합.
"""

import uuid

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.stamp_card import StampCard


class MergeService:
    """Handles deferred registration and account merge."""

    KAKAO_USERINFO_URL = "https://kapi.kakao.com/v2/user/me"

    def __init__(self, db: AsyncSession):
        self.db = db

    async def verify_kakao_token(self, access_token: str) -> dict:
        """Verify Kakao access token and fetch user info."""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                self.KAKAO_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            resp.raise_for_status()
            return resp.json()

    async def merge_accounts(
        self, guest_id: uuid.UUID, kakao_access_token: str
    ) -> tuple[Customer, bool]:
        """
        Merge guest account with Kakao login.

        Flow:
        1. Verify Kakao token → get kakao_id, nickname
        2. Check if kakao_id already linked to another account
           - If yes: merge guest's stamps into existing account
           - If no: update guest record with kakao_id
        3. Return (customer, merged_flag)
        """
        # 1. Verify Kakao token
        kakao_info = await self.verify_kakao_token(kakao_access_token)
        kakao_id = str(kakao_info["id"])
        nickname = (
            kakao_info.get("kakao_account", {})
            .get("profile", {})
            .get("nickname")
        )

        # 2. Find guest account
        result = await self.db.execute(
            select(Customer).where(Customer.guest_id == guest_id)
        )
        guest_customer = result.scalar_one_or_none()
        if guest_customer is None:
            raise ValueError("Guest account not found")

        # 3. Check if kakao_id already exists
        result = await self.db.execute(
            select(Customer).where(Customer.kakao_id == kakao_id)
        )
        existing_customer = result.scalar_one_or_none()

        if existing_customer is not None:
            # Merge: move guest's stamp_cards to existing account
            await self.db.execute(
                update(StampCard)
                .where(StampCard.customer_id == guest_customer.id)
                .values(customer_id=existing_customer.id)
            )
            # Update existing customer's nickname if needed
            if nickname and not existing_customer.nickname:
                existing_customer.nickname = nickname
            # Keep FCM token from guest if existing doesn't have one
            if guest_customer.fcm_token and not existing_customer.fcm_token:
                existing_customer.fcm_token = guest_customer.fcm_token

            await self.db.flush()
            return existing_customer, True
        else:
            # No merge needed: just link kakao_id to guest account
            guest_customer.kakao_id = kakao_id
            guest_customer.nickname = nickname
            await self.db.flush()
            return guest_customer, False
