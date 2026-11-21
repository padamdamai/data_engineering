"""
Seed script for the retail product catalog.

Run this file once before starting the application:

python seed_data.py

It creates or updates products in MongoDB Atlas so the order form has realistic
items to display.
"""

from pymongo import MongoClient
import os
from dotenv import load_dotenv
load_dotenv()

# Use the same Atlas connection string and database name as app.py.
# Replace the placeholder URI with your actual MongoDB Atlas connection string.
MONGODB_URI = os.getenv("MONGODB_URI")
DATABASE_NAME = "retail_order_management"


# This fixed catalog is intentionally small and realistic.
# Keeping it deterministic makes it easier to explain the same records every
# time the script is run.
PRODUCTS = [
    {
        "sku": "GRC-RCE-005",
        "name": "India Gate Basmati Rice",
        "category": "Staples",
        "unit": "5 kg bag",
        "price": 725.00,
        "active": True,
    },
    {
        "sku": "GRC-ATL-001",
        "name": "Aashirvaad Whole Wheat Atta",
        "category": "Staples",
        "unit": "5 kg bag",
        "price": 289.00,
        "active": True,
    },
    {
        "sku": "GRC-OIL-001",
        "name": "Fortune Sunflower Oil",
        "category": "Cooking Essentials",
        "unit": "1 litre pouch",
        "price": 142.00,
        "active": True,
    },
    {
        "sku": "GRC-MLK-001",
        "name": "Amul Taaza Toned Milk",
        "category": "Dairy",
        "unit": "1 litre carton",
        "price": 74.00,
        "active": True,
    },
    {
        "sku": "GRC-EGG-012",
        "name": "Fresh Farm Eggs",
        "category": "Dairy & Eggs",
        "unit": "pack of 12",
        "price": 108.00,
        "active": True,
    },
    {
        "sku": "GRC-TEA-500",
        "name": "Tata Tea Premium",
        "category": "Beverages",
        "unit": "500 g pack",
        "price": 272.00,
        "active": True,
    },
    {
        "sku": "GRC-DAL-001",
        "name": "Tata Sampann Toor Dal",
        "category": "Pulses",
        "unit": "1 kg pack",
        "price": 196.00,
        "active": True,
    },
    {
        "sku": "HOM-CLN-002",
        "name": "Lizol Citrus Floor Cleaner",
        "category": "Home Care",
        "unit": "2 litre bottle",
        "price": 389.00,
        "active": True,
    },
]


def seed_products() -> None:
    """Insert or update the fixed product catalog in MongoDB Atlas."""

    # MongoClient opens the connection to MongoDB Atlas. The timeout keeps a bad
    # URI or blocked IP address from waiting too long before showing an error.
    client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)

    # Select the database and the products collection.
    database = client[DATABASE_NAME]
    products = database["products"]

    # ping confirms the connection before writing data.
    client.admin.command("ping")

    # A unique index prevents two products with the same SKU from being created.
    # SKU means stock keeping unit, a common product identifier in retail.
    products.create_index("sku", unique=True)

    for product in PRODUCTS:
        # update_one with upsert=True means:
        # - if a product with this SKU exists, update it
        # - if it does not exist, insert it
        # This makes the script safe to run multiple times.
        products.update_one(
            {"sku": product["sku"]},
            {"$set": product},
            upsert=True,
        )

    active_count = products.count_documents({"active": True})
    print(f"Product catalog is ready: {active_count} active products")

    # Close the client because this script is short-lived.
    client.close()


# This block runs only when the file is executed directly with python
# seed_data.py. It does not run if another file imports seed_products.
if __name__ == "__main__":
    seed_products()
