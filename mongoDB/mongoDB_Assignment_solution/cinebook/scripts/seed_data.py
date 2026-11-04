"""Load seed data: 4 movies, 3 theaters (3 cities), 12 shows, 4 users.

Usage (run from the project root, AFTER apply_validation.py):
    python3 scripts/seed_data.py

Safe to run many times: it empties the collections first (delete_many keeps the
validation rules, unlike drop). The bookings collection is left empty on purpose;
your API fills it.
"""
import os
from datetime import datetime, timezone

from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv()
db = MongoClient(os.environ["MONGODB_URI"])[os.getenv("MONGODB_DB", "cinebook")]


def utc(y, m, d, hh, mm=0):
    """A real BSON date (not a string) so range queries and sorts work."""
    return datetime(y, m, d, hh, mm, tzinfo=timezone.utc)


# ---------------------------------------------------------------- movies
movies = [
    {"_id": "MOV-DUNE2", "title": "Dune: Part Two", "language": "English",
     "genres": ["Sci-Fi", "Adventure"], "duration_min": 166, "certification": "UA",
     "release_date": "2024-03-01", "cities": ["Delhi", "Mumbai", "Bengaluru"]},
    {"_id": "MOV-INTERSTELLAR", "title": "Interstellar", "language": "English",
     "genres": ["Sci-Fi", "Drama"], "duration_min": 169, "certification": "UA",
     "release_date": "2014-11-07", "cities": ["Delhi", "Mumbai"]},
    {"_id": "MOV-3IDIOTS", "title": "3 Idiots", "language": "Hindi",
     "genres": ["Comedy", "Drama"], "duration_min": 170, "certification": "U",
     "release_date": "2009-12-25", "cities": ["Delhi", "Mumbai", "Bengaluru"]},
    {"_id": "MOV-RRR", "title": "RRR", "language": "Telugu",
     "genres": ["Action", "Drama"], "duration_min": 182, "certification": "UA",
     "release_date": "2022-03-25", "cities": ["Mumbai", "Bengaluru"]},
]

# -------------------------------------------------------------- theaters
CATEGORIES = {"A-B": "PREMIUM", "C-E": "REGULAR"}


def screen(screen_id, name):
    return {"screen_id": screen_id, "name": name, "rows": ["A", "B", "C", "D", "E"],
            "seats_per_row": 10, "categories": CATEGORIES}


theaters = [
    {"_id": "THR-DEL-01", "name": "Downtown Cineplex", "city": "Delhi",
     "screens": [screen("SCR-1", "Audi 1"), screen("SCR-2", "Audi 2")]},
    {"_id": "THR-MUM-01", "name": "Marine Drive Cinemas", "city": "Mumbai",
     "screens": [screen("SCR-1", "Audi 1")]},
    {"_id": "THR-BLR-01", "name": "Koramangala Screens", "city": "Bengaluru",
     "screens": [screen("SCR-1", "Audi 1")]},
]
theater_by_id = {t["_id"]: t for t in theaters}


# ----------------------------------------------------------------- shows
def category_for(row, categories):
    """Turn {"A-B": "PREMIUM", "C-E": "REGULAR"} into a category for one row letter."""
    for span, cat in categories.items():
        lo, hi = span.split("-")
        if lo <= row <= hi:
            return cat
    raise ValueError(f"No category for row {row}")


def build_seats(scr):
    return [
        {"seat": f"{row}{n}", "category": category_for(row, scr["categories"]),
         "status": "AVAILABLE"}
        for row in scr["rows"] for n in range(1, scr["seats_per_row"] + 1)
    ]


# (show id, movie id, theater id, screen id, start time (UTC), prices)
show_plan = [
    ("SHW-000501", "MOV-DUNE2",        "THR-DEL-01", "SCR-1", utc(2026, 11, 10, 18, 30), (450, 300)),
    ("SHW-000502", "MOV-DUNE2",        "THR-DEL-01", "SCR-1", utc(2026, 11, 11, 21, 30), (450, 300)),
    ("SHW-000503", "MOV-3IDIOTS",      "THR-DEL-01", "SCR-2", utc(2026, 11, 10, 14, 0),  (400, 250)),
    ("SHW-000504", "MOV-INTERSTELLAR", "THR-DEL-01", "SCR-2", utc(2026, 11, 11, 19, 0),  (400, 250)),
    ("SHW-000505", "MOV-DUNE2",        "THR-MUM-01", "SCR-1", utc(2026, 11, 10, 20, 0),  (500, 350)),
    ("SHW-000506", "MOV-RRR",          "THR-MUM-01", "SCR-1", utc(2026, 11, 11, 18, 30), (500, 350)),
    ("SHW-000507", "MOV-3IDIOTS",      "THR-MUM-01", "SCR-1", utc(2026, 11, 12, 11, 0),  (450, 300)),
    ("SHW-000508", "MOV-INTERSTELLAR", "THR-MUM-01", "SCR-1", utc(2026, 11, 12, 18, 30), (500, 350)),
    ("SHW-000509", "MOV-DUNE2",        "THR-BLR-01", "SCR-1", utc(2026, 11, 10, 19, 0),  (480, 320)),
    ("SHW-000510", "MOV-RRR",          "THR-BLR-01", "SCR-1", utc(2026, 11, 11, 15, 30), (480, 320)),
    ("SHW-000511", "MOV-RRR",          "THR-BLR-01", "SCR-1", utc(2026, 11, 12, 21, 0),  (480, 320)),
    ("SHW-000512", "MOV-3IDIOTS",      "THR-BLR-01", "SCR-1", utc(2026, 11, 13, 17, 0),  (420, 280)),
]

shows = []
for show_id, movie_id, theater_id, screen_id, start, (premium, regular) in show_plan:
    theater = theater_by_id[theater_id]
    scr = next(s for s in theater["screens"] if s["screen_id"] == screen_id)
    seats = build_seats(scr)
    shows.append({
        "_id": show_id,
        "movie_id": movie_id,
        "theater_id": theater_id,
        "screen_id": screen_id,
        "city": theater["city"],              # denormalized so one index can serve browsing
        "start_time": start,
        "prices": {"PREMIUM": premium, "REGULAR": regular},
        "available_count": len(seats),        # kept in sync with $inc on every booking
        "seats": seats,
    })

# ----------------------------------------------------------------- users
users = [
    {"_id": "USR-1001", "name": "Aarav Sharma", "email": "aarav@example.com", "city": "Delhi"},
    {"_id": "USR-1002", "name": "Isha Verma",   "email": "isha@example.com",  "city": "Mumbai"},
    {"_id": "USR-1003", "name": "Rohan Mehta",  "email": "rohan@example.com", "city": "Bengaluru"},
    {"_id": "USR-1004", "name": "Diya Kapoor",  "email": "diya@example.com",  "city": "Delhi"},
]
for u in users:
    u["created_at"] = utc(2026, 11, 1, 9)

# ------------------------------------------------------------------ load
if __name__ == "__main__":
    for name, docs in [("movies", movies), ("theaters", theaters),
                       ("shows", shows), ("users", users)]:
        db[name].delete_many({})
        db[name].insert_many(docs)
        print(f"{name}: inserted {len(docs)} documents")
    print("bookings: left empty (created through the API)")