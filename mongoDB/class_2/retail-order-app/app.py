"""
Retail Order Management backend.

Browser form -> FastAPI endpoint -> validation -> MongoDB Atlas collection.
"""

from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import List, Literal
import os
from dotenv import load_dotenv
load_dotenv()

from bson import ObjectId
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator
from pymongo import MongoClient, ReturnDocument
from pymongo.errors import PyMongoError


# ---------------------------------------------------------------------------
# Application configuration
# ---------------------------------------------------------------------------

# Paste your MongoDB Atlas connection string here before running the app.
# The string usually starts with "mongodb+srv://" and contains username,
# password, cluster hostname, and connection options.
# it's dont have security if we mensioned the password here so we use env method like below
# MONGODB_URI = "mongodb+srv://padamdamai:<yourpassword>@mongodb-dev.1qpav8z.mongodb.net/"
MONGODB_URI = os.getenv("MONGODB_URI")

# This is the MongoDB database where the app stores product and order data.
DATABASE_NAME = "retail_order_management"

# BASE_DIR is the folder containing this app.py file.
# STATIC_DIR points to the static folder that contains HTML, CSS, and JS files.
BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"


# ---------------------------------------------------------------------------
# FastAPI application and MongoDB connection
# ---------------------------------------------------------------------------

# FastAPI creates the web application object. Every @app.get, @app.post, or
# @app.patch decorator below registers one URL route on this object.
app = FastAPI(title="Retail Order Management", version="1.0.0")

# This line tells FastAPI to serve files from the static directory whenever the
# browser requests a URL that begins with /static.
# Example: /static/styles.css returns static/styles.css.
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# MongoClient manages the connection pool to MongoDB Atlas. The timeout keeps
# mistakes in the connection string from making the UI wait for a long time.
mongo_client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)

# Select the database and collections used by this application.
database = mongo_client[DATABASE_NAME]
products_collection = database["products"]
orders_collection = database["orders"]


# ---------------------------------------------------------------------------
# Business constants
# ---------------------------------------------------------------------------

# These are the statuses an order can have during fulfillment.
ORDER_STATUSES = [
    "PLACED",
    "CONFIRMED",
    "PACKING",
    "READY",
    "DISPATCHED",
    "DELIVERED",
    "CANCELLED",
]

# This dictionary controls which status changes are allowed.
# Example: a PLACED order can become CONFIRMED or CANCELLED, but it cannot jump
# directly to DELIVERED. This keeps the business process realistic.
ALLOWED_STATUS_TRANSITIONS = {
    "PLACED": {"CONFIRMED", "CANCELLED"},
    "CONFIRMED": {"PACKING", "CANCELLED"},
    "PACKING": {"READY", "CANCELLED"},
    "READY": {"DISPATCHED", "CANCELLED"},
    "DISPATCHED": {"DELIVERED"},
    "DELIVERED": set(),
    "CANCELLED": set(),
}


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

# Pydantic BaseModel classes describe the JSON shape expected by the API.
# FastAPI automatically uses these models to validate incoming request bodies.


class CustomerInput(BaseModel):
    """Customer details sent by the browser when a user places an order."""

    # Field adds validation rules. For example, the name must be at least
    # 2 characters and no more than 80 characters.
    name: str = Field(min_length=2, max_length=80)

    # Indian mobile numbers commonly start from 6, 7, 8, or 9 and contain
    # exactly 10 digits. The regex enforces that shape.
    phone: str = Field(pattern=r"^[6-9][0-9]{9}$")

    # This simple regex checks for the common email pattern: text@text.text.
    email: str = Field(pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$")

    # field_validator runs custom cleanup logic for one or more fields.
    # @classmethod means Pydantic calls this method on the class, not on an
    # already-created object.
    @field_validator("name", "email")
    @classmethod
    def clean_text(cls, value: str) -> str:
        """Remove leading/trailing spaces before storing customer text."""

        return value.strip()


class AddressInput(BaseModel):
    """Delivery address sent by the browser."""

    address_line: str = Field(min_length=5, max_length=150)
    city: str = Field(min_length=2, max_length=60)

    # Indian PIN codes are 6 digits and do not start with zero.
    postal_code: str = Field(pattern=r"^[1-9][0-9]{5}$")

    @field_validator("address_line", "city")
    @classmethod
    def clean_text(cls, value: str) -> str:
        """Trim address text before saving it in MongoDB."""

        return value.strip()


class OrderItemInput(BaseModel):
    """One product and quantity selected in the order form."""

    # product_id is received as a string because JSON does not have ObjectId.
    # The backend later converts it to a MongoDB ObjectId.
    product_id: str

    # Quantity is limited to keep the scenario realistic for a small order.
    quantity: int = Field(ge=1, le=10)


class OrderInput(BaseModel):
    """Complete request body for POST /api/orders."""

    customer: CustomerInput
    delivery_address: AddressInput

    # At least one product is required to place an order.
    items: List[OrderItemInput] = Field(min_length=1)

    # Literal restricts the field to only these allowed values.
    payment_method: Literal["UPI", "CARD", "CASH_ON_DELIVERY"]
    delivery_slot: Literal[
        "09:00 AM - 12:00 PM",
        "12:00 PM - 03:00 PM",
        "03:00 PM - 06:00 PM",
        "06:00 PM - 09:00 PM",
    ]


class StatusInput(BaseModel):
    """Request body for PATCH /api/orders/{order_id}/status."""

    status: Literal[
        "PLACED",
        "CONFIRMED",
        "PACKING",
        "READY",
        "DISPATCHED",
        "DELIVERED",
        "CANCELLED",
    ]


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def money(value: Decimal) -> float:
    """
    Round a Decimal money value to two digits and return a JSON-safe number.

    Decimal is used for calculation because it avoids common floating-point
    rounding surprises with currency values.
    """

    return float(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def serialize_document(value):
    """
    Convert MongoDB-specific values into JSON-safe values.

    MongoDB stores document IDs as ObjectId values. Browsers cannot understand
    ObjectId directly, so this function walks through dictionaries and lists and
    converts every ObjectId into a string.
    """

    if isinstance(value, ObjectId):
        return str(value)

    if isinstance(value, list):
        return [serialize_document(item) for item in value]

    if isinstance(value, dict):
        return {key: serialize_document(item) for key, item in value.items()}

    return value


def parse_object_id(value: str) -> ObjectId:
    """
    Convert a URL string into a MongoDB ObjectId.

    If the value is not a valid ObjectId, the API returns a clear 400 response
    instead of allowing a lower-level MongoDB error to reach the user.
    """

    try:
        return ObjectId(value)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid order identifier") from exc


# ---------------------------------------------------------------------------
# Page route
# ---------------------------------------------------------------------------


@app.get("/", include_in_schema=False)
def home() -> FileResponse:
    """
    Serve the main web page.

    @app.get("/") means this function runs when the browser requests GET /.
    include_in_schema=False hides this HTML page route from the generated API
    documentation because it is not a JSON API endpoint.
    """

    return FileResponse(STATIC_DIR / "index.html")


@app.get("/styles.css", include_in_schema=False)
def stylesheet() -> FileResponse:
    """
    Serve the CSS file when index.html is loaded from the root URL.

    The HTML uses a relative path, href="styles.css", so a browser at
    http://127.0.0.1:8000 requests /styles.css. This route returns the same CSS
    file that is also available from /static/styles.css.
    """

    return FileResponse(STATIC_DIR / "styles.css", media_type="text/css")


@app.get("/app.js", include_in_schema=False)
def browser_javascript() -> FileResponse:
    """
    Serve the browser JavaScript file when index.html is loaded from the root URL.

    The HTML uses src="app.js", so FastAPI needs this route for the correct
    script to load at http://127.0.0.1:8000.
    """

    return FileResponse(STATIC_DIR / "app.js", media_type="application/javascript")


# ---------------------------------------------------------------------------
# API routes
# ---------------------------------------------------------------------------


@app.get("/api/health")
def health() -> dict:
    """
    Check whether the backend can reach MongoDB Atlas.

    The frontend calls this endpoint to show "Atlas connected" or
    "Atlas unavailable" in the top bar.
    """

    try:
        # ping is a lightweight MongoDB command used only to confirm that the
        # database connection works.
        database.command("ping")
        return {"status": "ok", "database": DATABASE_NAME}
    except PyMongoError as exc:
        raise HTTPException(
            status_code=503,
            detail="MongoDB connection failed. Check the Atlas connection string and network access.",
        ) from exc


@app.get("/api/products")
def list_products() -> list:
    """
    Return active products for the order form.

    @app.get("/api/products") registers a GET endpoint. The browser calls it
    when loading the catalog section.
    """

    try:
        # find({"active": True}) returns only products that can currently be
        # ordered. sort("name", 1) sorts alphabetically from A to Z.
        products = products_collection.find({"active": True}).sort("name", 1)
        return [serialize_document(product) for product in products]
    except PyMongoError as exc:
        raise HTTPException(status_code=503, detail="Could not load products from MongoDB") from exc


@app.post("/api/orders", status_code=201)
def create_order(order: OrderInput) -> dict:
    """
    Create a new order document in MongoDB.

    @app.post means this function handles POST requests. FastAPI reads the JSON
    body, validates it with OrderInput, and passes the validated object as the
    order argument.
    """

    # Keep the same product from appearing twice in one order. This makes the
    # order easier to read and avoids duplicate line items for the same SKU.
    requested_ids = [item.product_id for item in order.items]
    if len(requested_ids) != len(set(requested_ids)):
        raise HTTPException(status_code=400, detail="Each product can appear only once")

    # Convert product ID strings from JSON into MongoDB ObjectId values before
    # querying the products collection.
    try:
        object_ids = [ObjectId(product_id) for product_id in requested_ids]
    except Exception as exc:
        raise HTTPException(status_code=400, detail="One or more product identifiers are invalid") from exc

    try:
        # Load product documents from MongoDB instead of trusting product names
        # or prices sent by the browser. This is important because browser data
        # can be edited by a user before submission.
        product_documents = list(
            products_collection.find({"_id": {"$in": object_ids}, "active": True})
        )
        products_by_id = {str(product["_id"]): product for product in product_documents}

        # If any requested product is missing or inactive, the order should not
        # be created.
        if len(products_by_id) != len(requested_ids):
            raise HTTPException(status_code=400, detail="One or more products are unavailable")

        line_items = []
        subtotal = Decimal("0")

        # Build line items from MongoDB product data and calculate totals on the
        # server. The frontend only sends product_id and quantity.
        for requested_item in order.items:
            product = products_by_id[requested_item.product_id]
            unit_price = Decimal(str(product["price"]))
            line_total = unit_price * requested_item.quantity
            subtotal += line_total

            line_items.append(
                {
                    "product_id": product["_id"],
                    "sku": product["sku"],
                    "name": product["name"],
                    "category": product["category"],
                    "unit": product["unit"],
                    "unit_price": money(unit_price),
                    "quantity": requested_item.quantity,
                    "line_total": money(line_total),
                }
            )

        # Business rule: delivery is free on orders of 500 INR or more.
        delivery_fee = Decimal("0") if subtotal >= Decimal("500") else Decimal("40")
        grand_total = subtotal + delivery_fee

        # Store UTC timestamps so the data remains consistent across machines
        # and time zones.
        current_time = datetime.now(timezone.utc)

        # This is the final MongoDB order document. It embeds customer, address,
        # items, pricing, current status, and status history in one document.
        order_document = {
            "customer": order.customer.model_dump(),
            "delivery_address": order.delivery_address.model_dump(),
            "items": line_items,
            "pricing": {
                "subtotal": money(subtotal),
                "delivery_fee": money(delivery_fee),
                "grand_total": money(grand_total),
                "currency": "INR",
            },
            "payment_method": order.payment_method,
            "delivery_slot": order.delivery_slot,
            "status": "PLACED",
            "status_history": [{"status": "PLACED", "changed_at": current_time}],
            "created_at": current_time,
            "updated_at": current_time,
        }

        # insert_one writes the document into MongoDB and returns the generated
        # _id. Then find_one reloads the stored document so the API response
        # matches exactly what MongoDB has saved.
        result = orders_collection.insert_one(order_document)
        created_order = orders_collection.find_one({"_id": result.inserted_id})
        return serialize_document(created_order)
    except HTTPException:
        # Re-raise expected API errors without changing their status code.
        raise
    except PyMongoError as exc:
        raise HTTPException(status_code=503, detail="Could not save the order to MongoDB") from exc


@app.get("/api/orders")
def list_orders() -> list:
    """
    Return recent orders for the order-tracking view.

    The newest orders are shown first, and the result is limited to 50 so the UI
    remains fast and easy to read.
    """

    try:
        orders = orders_collection.find().sort("created_at", -1).limit(50)
        return [serialize_document(order) for order in orders]
    except PyMongoError as exc:
        raise HTTPException(status_code=503, detail="Could not load orders from MongoDB") from exc


@app.patch("/api/orders/{order_id}/status")
def update_order_status(order_id: str, status_update: StatusInput) -> dict:
    """
    Update the fulfillment status of one order.

    @app.patch is used because only part of the order document changes: status,
    updated_at, and status_history.

    The {order_id} part of the URL is a path parameter. FastAPI reads it from
    the URL and passes it into this function as the order_id argument.
    """

    object_id = parse_object_id(order_id)

    try:
        # First read the current order so we can validate the status transition.
        existing_order = orders_collection.find_one({"_id": object_id})
        if not existing_order:
            raise HTTPException(status_code=404, detail="Order not found")

        current_status = existing_order["status"]
        requested_status = status_update.status

        # Reject unrealistic jumps, such as PLACED directly to DELIVERED.
        if requested_status not in ALLOWED_STATUS_TRANSITIONS[current_status]:
            allowed = sorted(ALLOWED_STATUS_TRANSITIONS[current_status])
            allowed_text = ", ".join(allowed) if allowed else "none"
            raise HTTPException(
                status_code=400,
                detail=f"Cannot change {current_status} to {requested_status}. Allowed: {allowed_text}",
            )

        current_time = datetime.now(timezone.utc)

        # find_one_and_update changes the order and returns the updated document.
        # The filter includes the current status so two users cannot accidentally
        # update the same order from the same old status at the same time.
        updated_order = orders_collection.find_one_and_update(
            {"_id": object_id, "status": current_status},
            {
                "$set": {"status": requested_status, "updated_at": current_time},
                "$push": {
                    "status_history": {
                        "status": requested_status,
                        "changed_at": current_time,
                    }
                },
            },
            return_document=ReturnDocument.AFTER,
        )

        if not updated_order:
            raise HTTPException(status_code=409, detail="Order was updated by another request")

        return serialize_document(updated_order)
    except HTTPException:
        raise
    except PyMongoError as exc:
        raise HTTPException(status_code=503, detail="Could not update the order in MongoDB") from exc
