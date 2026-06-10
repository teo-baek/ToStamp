"""
수용 기준 테스트 — 기획서(tostamp-FINAL-기획-설계.md) §10의 testable 항목.

- 멱등 적립: 동일 QR 토큰 재시도 시 이중적립 0
- reward_price_krw는 stamp_goal로 나누어떨어져야 함
- 거래소 호가 ≤ 액면가 강제
- C2C 거래 도장은 발행 매장 카드로만 이전(매장 전용 사용)
- 준비금 불변식: money_outstanding ≤ total_cash_in
- 머니 외부 출금 API 부재
- 에이전트 예산 가드: budget_stamps_max 초과 발급 차단
"""

import uuid as uuidlib
from datetime import datetime, timedelta, timezone

from httpx import AsyncClient

# ── 헬퍼 ─────────────────────────────────────────────


async def _guest(client: AsyncClient) -> dict:
    r = await client.post("/api/v1/auth/guest")
    assert r.status_code == 200
    return r.json()


def _unique_phone() -> str:
    # stores.owner_phone UNIQUE 제약 → 테스트마다 고유 번호
    return f"010-{uuidlib.uuid4().int % 10**8:08d}"


async def _store(client: AsyncClient, goal: int = 10, price: int = 4000) -> dict:
    r = await client.post(
        "/api/v1/stores/",
        json={
            "owner_phone": _unique_phone(),
            "store_name": "수용기준 카페",
            "stamp_goal": goal,
            "reward_price_krw": price,
            "reward_description": "아메리카노 1잔",
        },
    )
    assert r.status_code == 201
    return r.json()


async def _earn(client: AsyncClient, qr_token: str, store_id: str):
    return await client.post(
        "/api/v1/stamps/earn",
        json={"qr_token": qr_token, "store_id": store_id},
    )


async def _fresh_token(client: AsyncClient, guest_id: str) -> str:
    r = await client.post(
        "/api/v1/auth/qr/refresh", params={"guest_id": guest_id}
    )
    assert r.status_code == 200
    return r.json()["qr_token"]


async def _earn_n(client: AsyncClient, guest: dict, store_id: str, n: int):
    """토큰을 갱신해가며 n회 적립."""
    token = guest["qr_token"]
    for _ in range(n):
        r = await _earn(client, token, store_id)
        assert r.status_code == 200
        token = await _fresh_token(client, guest["guest_id"])


# ── §10 멱등성: 동일 QR 재시도 시 이중적립 0 ──────────


async def test_earn_is_idempotent_per_token(client: AsyncClient):
    guest = await _guest(client)
    store = await _store(client)

    first = await _earn(client, guest["qr_token"], store["id"])
    assert first.status_code == 200
    assert first.json()["current_stamps"] == 1

    # 동일 토큰 재시도(더블탭/재전송) → 거부되고 적립 수 불변
    second = await _earn(client, guest["qr_token"], store["id"])
    assert second.status_code == 400

    cards = (await client.get(f"/api/v1/stamps/cards/{guest['guest_id']}")).json()
    assert len(cards) == 1
    assert cards[0]["current_stamps"] == 1


# ── §10 나눠떨어짐 강제 ───────────────────────────────


async def test_reward_price_must_divide_stamp_goal(client: AsyncClient):
    r = await client.post(
        "/api/v1/stores/",
        json={
            "owner_phone": _unique_phone(),
            "store_name": "불량 가격 매장",
            "stamp_goal": 10,
            "reward_price_krw": 4001,  # 10으로 나누어떨어지지 않음
            "reward_description": "테스트",
        },
    )
    assert r.status_code == 422


# ── §10 호가 ≤ 액면가 강제 ───────────────────────────


async def test_listing_ask_price_capped_at_face_value(client: AsyncClient):
    store = await _store(client)  # 액면가 400원
    seller = await _guest(client)
    await _earn_n(client, seller, store["id"], 2)

    over = await client.post(
        f"/api/v1/exchange/{seller['guest_id']}/listings",
        json={"store_id": store["id"], "qty": 2, "ask_price_krw": 801},
    )
    assert over.status_code == 400

    ok = await client.post(
        f"/api/v1/exchange/{seller['guest_id']}/listings",
        json={"store_id": store["id"], "qty": 2, "ask_price_krw": 800},
    )
    assert ok.status_code in (200, 201)


# ── §10 매장 전용 사용 + 준비금 불변식 ────────────────


async def test_c2c_trade_locks_stamps_to_issuing_store(client: AsyncClient):
    store = await _store(client)  # 액면가 400원
    seller = await _guest(client)
    buyer = await _guest(client)

    await _earn_n(client, seller, store["id"], 3)

    topup = await client.post(
        f"/api/v1/exchange/money/{buyer['guest_id']}/topup",
        json={"amount_krw": 1000},
    )
    assert topup.status_code == 200

    listing = await client.post(
        f"/api/v1/exchange/{seller['guest_id']}/listings",
        json={"store_id": store["id"], "qty": 2, "ask_price_krw": 800},
    )
    assert listing.status_code in (200, 201)
    listing_id = listing.json()["id"]

    buy = await client.post(
        f"/api/v1/exchange/{buyer['guest_id']}/listings/{listing_id}/buy"
    )
    assert buy.status_code == 200

    # 구매한 도장은 '발행 매장' 카드로만 귀속 (타 매장 사용 경로 없음)
    buyer_cards = (
        await client.get(f"/api/v1/stamps/cards/{buyer['guest_id']}")
    ).json()
    assert len(buyer_cards) == 1
    assert buyer_cards[0]["store_id"] == store["id"]
    assert buyer_cards[0]["current_stamps"] == 2

    seller_cards = (
        await client.get(f"/api/v1/stamps/cards/{seller['guest_id']}")
    ).json()
    assert seller_cards[0]["current_stamps"] == 1

    # 머니 이동: 구매자 1000 - 800 = 200, 판매자 + 800
    buyer_bal = (
        await client.get(f"/api/v1/exchange/money/{buyer['guest_id']}")
    ).json()["balance_krw"]
    seller_bal = (
        await client.get(f"/api/v1/exchange/money/{seller['guest_id']}")
    ).json()["balance_krw"]
    assert buyer_bal == 200
    assert seller_bal == 800

    # 준비금 불변식: 머니 총잔액 ≤ 들어온 현금 총액 (100% reserve)
    reserve = (await client.get("/api/v1/exchange/reserve")).json()
    assert reserve["solvent"] is True
    assert (
        reserve["customer_money_balance_krw"] <= reserve["total_cash_in_krw"]
    )


# ── §10 머니 외부 출금 API 부재 ──────────────────────


async def test_no_money_withdrawal_api():
    from app.main import app

    paths = [getattr(route, "path", "").lower() for route in app.routes]
    forbidden = ("withdraw", "payout", "cashout", "cash-out")
    offending = [
        p for p in paths if any(word in p for word in forbidden)
    ]
    assert offending == [], f"머니 출금성 엔드포인트 발견: {offending}"


# ── §10 에이전트 예산 가드 ───────────────────────────


async def test_agent_budget_guard(client: AsyncClient):
    store = await _store(client)
    store_uuid = uuidlib.UUID(store["id"])

    policy = await client.put(
        f"/api/v1/marketing/stores/{store['id']}/agent/policy",
        json={"budget_stamps_max": 2, "automation_mode": "auto"},
    )
    assert policy.status_code == 200

    # at_risk 고객 5명 구성: 방문 2회, 마지막 방문 15일 전
    from app.database import async_session
    from app.models import Customer, StampCard, Visit

    now = datetime.now(timezone.utc)
    async with async_session() as db:
        for _ in range(5):
            customer = Customer(guest_id=uuidlib.uuid4())
            db.add(customer)
            await db.flush()
            card = StampCard(
                customer_id=customer.id,
                store_id=store_uuid,
                current_stamps=2,
                created_at=now - timedelta(days=40),
            )
            db.add(card)
            await db.flush()
            for days_ago in (20, 15):
                db.add(
                    Visit(
                        stamp_card_id=card.id,
                        stamped_by=store_uuid,
                        stamped_at=now - timedelta(days=days_ago),
                    )
                )
        await db.commit()

    first = await client.post(
        f"/api/v1/marketing/stores/{store['id']}/agent/run"
    )
    assert first.status_code == 200
    run1 = first.json()
    assert run1["budget_max"] == 2
    assert run1["issued"] <= 2

    # 재실행: 예산 소진 + 최근 접촉 쿨다운 → 추가 발급은 남은 예산 이내
    second = await client.post(
        f"/api/v1/marketing/stores/{store['id']}/agent/run"
    )
    assert second.status_code == 200
    run2 = second.json()
    assert run1["issued"] + run2["issued"] <= 2
    assert run2["budget_consumed"] <= 2
