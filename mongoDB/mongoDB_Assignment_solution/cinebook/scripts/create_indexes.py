"""Create the indexes for the query patterns of Parts C and D.

Usage (run from the project root):
    python3 scripts/create_indexes.py

ESR rule for compound indexes: Equality fields first, then Sort field, then Range field.
Safe to run many times: creating an index that already exists does nothing.
"""
import os

from dotenv import load_dotenv
from pymongo import ASCENDING, DESCENDING, MongoClient

load_dotenv()
db = MongoClient(os.environ["MONGODB_URI"])[os.getenv("MONGODB_DB", "cinebook")]

INDEXES = [
    # (collection, keys, name)
    # 1. GET /movies/{id}/shows : city = ? AND movie_id = ?, start_time range + sort
    #    E = city, movie_id   S/R = start_time (sort and range on the same field)
    ("shows", [("city", ASCENDING), ("movie_id", ASCENDING), ("start_time", ASCENDING)],
     "shows_city_movie_start"),

    # 2. Shows of one theater in time order (theater schedule, analytics join)
    ("shows", [("theater_id", ASCENDING), ("start_time", ASCENDING)],
     "shows_theater_start"),

    # 3. GET /movies?city=&language= : multikey on the cities array
    ("movies", [("cities", ASCENDING), ("language", ASCENDING)],
     "movies_city_language"),

    # 4. GET /movies?genre= : multikey on the genres array
    ("movies", [("genres", ASCENDING)],
     "movies_genres"),

    # 5. GET /users/{id}/bookings : user = ?, newest first  (E then S)
    ("bookings", [("user_id", ASCENDING), ("created_at", DESCENDING)],
     "bookings_user_created"),

    # 6. Bookings of one show (occupancy, checks)  E = show_id, status
    ("bookings", [("show_id", ASCENDING), ("status", ASCENDING)],
     "bookings_show_status"),

    # 7. Analytics: $match status = CONFIRMED, then group by movie
    ("bookings", [("status", ASCENDING), ("movie_id", ASCENDING)],
     "bookings_status_movie"),
]

if __name__ == "__main__":
    for coll, keys, name in INDEXES:
        db[coll].create_index(keys, name=name)
        print(f"{coll}: created index {name}")

    print("\nIndexes now in the database:")
    for coll in ["movies", "shows", "bookings"]:
        for idx in db[coll].list_indexes():
            print(f"  {coll}.{idx['name']}: {dict(idx['key'])}")