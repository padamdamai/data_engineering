"""Create demo bookings THROUGH THE API so analytics have meaningful data."""
import random
import sys

import httpx

BASE = "http://127.0.0.1:8000"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 80
random.seed(42)                                   # same demo data every time

USERS = ["USR-1001", "USR-1002", "USR-1003", "USR-1004"]
SHOWS = [f"SHW-0005{n:02d}" for n in range(1, 13)]            # SHW-000501 .. SHW-000512
WEIGHTS = [10, 6, 3, 4, 9, 5, 2, 3, 8, 4, 3, 2]               # busier vs quieter shows

created = skipped = 0
with httpx.Client(timeout=30) as client:
    for _ in range(N):
        show = random.choices(SHOWS, WEIGHTS)[0]
        seats = client.get(f"{BASE}/shows/{show}/seats").json()["seats"]
        free = [s["seat"] for s in seats if s["status"] == "AVAILABLE"]
        if not free:
            skipped += 1
            continue
        pick = random.sample(free, min(len(free), random.randint(1, 4)))
        r = client.post(
            f"{BASE}/bookings",
            json={"user_id": random.choice(USERS), "show_id": show, "seats": pick},
        )
        if r.status_code == 201:
            created += 1
        else:
            skipped += 1

print(f"Done: {created} bookings created, {skipped} skipped")