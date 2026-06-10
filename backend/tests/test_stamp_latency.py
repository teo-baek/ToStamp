"""
Latency Test Harness — 스캔→적립 응답 지연시간 검증.
CI/CD 파이프라인에서 1초 미만 assertion으로 게이트 역할.
"""

import asyncio
import os
import statistics
import sys
import time

import httpx


# cloudbuild latency-test 스텝이 배포된 Cloud Run URL을 API_BASE로 주입한다.
API_BASE = os.environ.get("API_BASE", "http://localhost:8080")
LATENCY_THRESHOLD_MS = 1000  # 1초


async def measure_stamp_latency(client: httpx.AsyncClient) -> float:
    """Measure full stamp-earn round-trip latency in milliseconds."""
    # Step 1: Create a guest
    start = time.perf_counter()
    resp = await client.post(f"{API_BASE}/api/v1/auth/guest")
    guest_data = resp.json()

    # Step 2: Earn a stamp
    resp = await client.post(
        f"{API_BASE}/api/v1/stamps/earn",
        json={
            "qr_token": guest_data["qr_token"],
            "store_id": "00000000-0000-0000-0000-000000000001",  # Test store
        },
    )
    end = time.perf_counter()

    latency_ms = (end - start) * 1000
    return latency_ms


async def run_latency_tests(num_iterations: int = 10):
    """Run multiple latency measurements and report statistics."""
    print(f"\n{'='*60}")
    print(f"  ToStamp Latency Test Harness")
    print(f"  Target: < {LATENCY_THRESHOLD_MS}ms per stamp-earn round-trip")
    print(f"  Iterations: {num_iterations}")
    print(f"{'='*60}\n")

    async with httpx.AsyncClient(timeout=10.0) as client:
        # Health check
        try:
            resp = await client.get(f"{API_BASE}/health")
            resp.raise_for_status()
            print("✅ API is healthy\n")
        except Exception as e:
            print(f"❌ API health check failed: {e}")
            sys.exit(1)

        latencies = []
        for i in range(num_iterations):
            try:
                latency = await measure_stamp_latency(client)
                latencies.append(latency)
                status = "✅" if latency < LATENCY_THRESHOLD_MS else "❌"
                print(f"  [{i+1:2d}/{num_iterations}] {status} {latency:7.1f}ms")
            except Exception as e:
                print(f"  [{i+1:2d}/{num_iterations}] ❌ Error: {e}")

    if not latencies:
        print("\n❌ No successful measurements")
        sys.exit(1)

    # Statistics
    avg = statistics.mean(latencies)
    p50 = statistics.median(latencies)
    p99 = sorted(latencies)[int(len(latencies) * 0.99)]
    max_latency = max(latencies)

    print(f"\n{'─'*60}")
    print(f"  Results:")
    print(f"  Average: {avg:.1f}ms")
    print(f"  P50:     {p50:.1f}ms")
    print(f"  P99:     {p99:.1f}ms")
    print(f"  Max:     {max_latency:.1f}ms")
    print(f"{'─'*60}")

    # Assert P99 < threshold
    if p99 < LATENCY_THRESHOLD_MS:
        print(f"\n✅ PASS — P99 ({p99:.1f}ms) < {LATENCY_THRESHOLD_MS}ms threshold")
    else:
        print(f"\n❌ FAIL — P99 ({p99:.1f}ms) >= {LATENCY_THRESHOLD_MS}ms threshold")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(run_latency_tests())
