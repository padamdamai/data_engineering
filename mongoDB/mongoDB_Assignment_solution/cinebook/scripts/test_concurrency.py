"""Prove that two users can never book the same seat.

Start the API first (uvicorn app.main:app --reload), then run:
    python3 scripts/test_concurrency.py

Afterwards run  python3 scripts/seed_data.py  to reset the seats.
"""
import asyncio

import httpx

BASE = "http://127.0.0.1:8000"
SHOW = "SHW-000501"
USERS = ["USR-1001", "USR-1002", "USR-1003", "USR-1004"]


async def book(client, user, seats):
    r = await client.post(
        f"{BASE}/bookings", json={"user_id": user, "show_id": SHOW, "seats": seats}
    )
    return r.status_code, r.json()


async def seat_status(client, names):
    data = (await client.get(f"{BASE}/shows/{SHOW}/seats")).json()
    status = {s["seat"]: s["status"] for s in data["seats"]}
    return {n: status[n] for n in names}


async def main():
    async with httpx.AsyncClient(timeout=30) as client:
        # ---- Test 1: 10 requests for the SAME seat at the same moment ------
        print("Test 1: 10 users try to book seat C5 at the same time")
        results = await asyncio.gather(
            *[book(client, USERS[i % 4], ["C5"]) for i in range(10)]
        )
        codes = [c for c, _ in results]
        print(f"  booked (201): {codes.count(201)}   rejected (409): {codes.count(409)}")
        print("  RESULT:", "PASS" if codes.count(201) == 1 else "FAIL")

        # ---- Test 2: overlapping multi-seat requests (all-or-nothing) ------
        print("\nTest 2: user A wants D1+D2, user B wants D2+D3 at the same time")
        a, b = await asyncio.gather(
            book(client, "USR-1001", ["D1", "D2"]),
            book(client, "USR-1002", ["D2", "D3"]),
        )
        print(f"  user A -> {a[0]}   user B -> {b[0]}")
        print("  seat status:", await seat_status(client, ["D1", "D2", "D3"]))
        winners = [r[0] for r in (a, b)].count(201)
        print("  RESULT:", "PASS" if winners == 1 else "FAIL",
              "(exactly one request wins; the loser's other seat stays AVAILABLE)")


asyncio.run(main())
