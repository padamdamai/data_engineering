"""Create the collections and attach $jsonSchema validation to shows and bookings.

Usage (run from the project root):
    python3 scripts/apply_validation.py         # validationAction = error (reject bad documents)
    python3 scripts/apply_validation.py warn    # validationAction = warn  (only log bad documents)

Safe to run many times: if a collection already exists, only its validator is updated.
"""
import os
import sys

from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv()
db = MongoClient(os.environ["MONGODB_URI"])[os.getenv("MONGODB_DB", "cinebook")]
ACTION = sys.argv[1] if len(sys.argv) > 1 else "error"

SEAT_STATUS = ["AVAILABLE", "HELD", "BOOKED"]          # HELD is used by the bonus part
BOOKING_STATUS = ["CONFIRMED", "HELD", "CANCELLED"]
INT = ["int", "long"]                                   # Python ints may be stored as either

shows_schema = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "movie_id", "theater_id", "screen_id", "city",
                     "start_time", "prices", "available_count", "seats"],
        "properties": {
            "_id": {"bsonType": "string"},
            "movie_id": {"bsonType": "string"},
            "theater_id": {"bsonType": "string"},
            "screen_id": {"bsonType": "string"},
            "city": {"bsonType": "string"},
            "start_time": {"bsonType": "date"},
            "prices": {
                "bsonType": "object",
                "required": ["PREMIUM", "REGULAR"],
                "properties": {
                    "PREMIUM": {"bsonType": "number", "minimum": 0},
                    "REGULAR": {"bsonType": "number", "minimum": 0},
                },
            },
            "available_count": {"bsonType": INT, "minimum": 0},
            "seats": {
                "bsonType": "array",
                "minItems": 1,
                "items": {
                    "bsonType": "object",
                    "required": ["seat", "category", "status"],
                    "properties": {
                        "seat": {"bsonType": "string"},
                        "category": {"enum": ["PREMIUM", "REGULAR"]},
                        "status": {"enum": SEAT_STATUS},
                    },
                },
            },
        },
    }
}

bookings_schema = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "show_id", "user_id", "movie_id", "movie_title",
                     "seats", "price_per_seat", "amount", "status", "created_at"],
        "properties": {
            "_id": {"bsonType": "string"},
            "show_id": {"bsonType": "string"},
            "user_id": {"bsonType": "string"},
            "movie_id": {"bsonType": "string"},
            "movie_title": {"bsonType": "string"},
            "theater_name": {"bsonType": "string"},
            "start_time": {"bsonType": "date"},
            "seats": {
                "bsonType": "array",
                "minItems": 1,
                "uniqueItems": True,
                "items": {"bsonType": "string"},
            },
            "price_per_seat": {"bsonType": "number", "minimum": 0},
            "amount": {"bsonType": "number", "minimum": 0},
            "status": {"enum": BOOKING_STATUS},
            "created_at": {"bsonType": "date"},
        },
    }
}


def apply(name, schema):
    if name in db.list_collection_names():
        db.command("collMod", name, validator=schema,
                   validationLevel="strict", validationAction=ACTION)
        print(f"Updated validation on '{name}' (action={ACTION})")
    else:
        db.create_collection(name, validator=schema,
                             validationLevel="strict", validationAction=ACTION)
        print(f"Created '{name}' with validation (action={ACTION})")


if __name__ == "__main__":
    apply("shows", shows_schema)
    apply("bookings", bookings_schema)
    # plain collections (no validation required by the assignment)
    for name in ["movies", "theaters", "users"]:
        if name not in db.list_collection_names():
            db.create_collection(name)
            print(f"Created '{name}'")