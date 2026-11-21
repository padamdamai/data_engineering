import os
from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import WriteError

load_dotenv()
db = MongoClient(os.environ["MONGODB_URI"])["cinebook"]

try:
    db.bookings.insert_one({"_id": "BAD", "status": "WRONG"})
    print("Inserted (validation is NOT working)")
except WriteError as e:
    print("Rejected:", e.details["errmsg"])