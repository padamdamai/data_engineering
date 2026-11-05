"""CineBook FastAPI backend.

Run from the project root (venv active):
    uvicorn app.main:app --reload
Interactive docs: http://127.0.0.1:8000/docs
"""
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from app import pipelines
from app.db import db

app = FastAPI(title="CineBook API")


class BookingIn(BaseModel):
    user_id: str
    show_id: str
    seats: List[str] = Field(min_length=1, max_length=10)


# ------------------------------------------------------------------ health
@app.get("/health")
async def health():
    await db.command("ping")
    return {"status": "ok"}


# ------------------------------------------------------------------ movies
@app.get("/movies")
async def list_movies(
    city: Optional[str] = None,
    language: Optional[str] = None,
    genre: Optional[str] = None,
):
    """Browse movies. Uses indexes movies_city_language and movies_genres."""
    query = {}
    if city:
        query["cities"] = city
    if language:
        query["language"] = language
    if genre:
        query["genres"] = genre
    return await db.movies.find(query).to_list(100)


@app.get("/movies/{movie_id}/shows")
async def list_shows(
    movie_id: str,
    city: Optional[str] = None,
    date: Optional[str] = Query(None, description="YYYY-MM-DD (UTC)"),
):
    """Shows of one movie, in time order. Uses index shows_city_movie_start."""
    if not await db.movies.find_one({"_id": movie_id}, {"_id": 1}):
        raise HTTPException(404, "Movie not found")

    query = {"movie_id": movie_id}
    if city:
        query["city"] = city
    if date:
        try:
            day = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            raise HTTPException(400, "date must be in YYYY-MM-DD format")
        query["start_time"] = {"$gte": day, "$lt": day + timedelta(days=1)}

    # project away the big seats array: the list view does not need it
    return await db.shows.find(query, {"seats": 0}).sort("start_time", 1).to_list(100)


# ------------------------------------------------------------------- seats
@app.get("/shows/{show_id}/seats")
async def show_seats(show_id: str):
    show = await db.shows.find_one(
        {"_id": show_id}, {"seats": 1, "available_count": 1, "prices": 1}
    )
    if not show:
        raise HTTPException(404, "Show not found")
    return {
        "show_id": show["_id"],
        "available_count": show["available_count"],
        "prices": show["prices"],
        "seats": show["seats"],
    }


# --------------------------------------------------------------- bookings
@app.post("/bookings", status_code=201)
async def create_booking(req: BookingIn):
    seats = [s.strip().upper() for s in req.seats]
    if len(set(seats)) != len(seats):
        raise HTTPException(400, "Duplicate seats in the request")

    # ---- 1. plain reads: validate input and work out the price -----------
    if not await db.users.find_one({"_id": req.user_id}, {"_id": 1}):
        raise HTTPException(404, "User not found")

    show = await db.shows.find_one({"_id": req.show_id})
    if not show:
        raise HTTPException(404, "Show not found")

    category_of = {s["seat"]: s["category"] for s in show["seats"]}
    unknown = [s for s in seats if s not in category_of]
    if unknown:
        raise HTTPException(400, f"Unknown seats for this show: {unknown}")

    movie = await db.movies.find_one({"_id": show["movie_id"]})
    theater = await db.theaters.find_one({"_id": show["theater_id"]})

    seat_prices = {s: show["prices"][category_of[s]] for s in seats}
    amount = sum(seat_prices.values())

    # ---- 2. THE ATOMIC STEP: reserve every seat in ONE update ------------
    # The filter matches the show only if EVERY requested seat is AVAILABLE.
    # If even one seat is taken, nothing matches and nothing is changed.
    result = await db.shows.update_one(
        {
            "_id": req.show_id,
            "$and": [
                {"seats": {"$elemMatch": {"seat": s, "status": "AVAILABLE"}}}
                for s in seats
            ],
        },
        {
            "$set": {"seats.$[s].status": "BOOKED"},
            "$inc": {"available_count": -len(seats)},
        },
        array_filters=[{"s.seat": {"$in": seats}}],
    )

    if result.modified_count != 1:
        # lost the race (or seat already booked): tell the user which seats
        fresh = await db.shows.find_one({"_id": req.show_id}, {"seats": 1})
        taken = [
            x["seat"] for x in fresh["seats"]
            if x["seat"] in seats and x["status"] != "AVAILABLE"
        ]
        raise HTTPException(
            409,
            detail={
                "message": "Some seats are no longer available. Nothing was booked.",
                "unavailable": taken,
            },
        )

    # ---- 3. seats are ours: record the booking ---------------------------
    booking = {
        "_id": "BKG-" + uuid.uuid4().hex[:8],
        "show_id": show["_id"],
        "user_id": req.user_id,
        "movie_id": show["movie_id"],
        "movie_title": movie["title"],              # denormalized on purpose
        "theater_name": theater["name"],            # denormalized on purpose
        "start_time": show["start_time"],           # denormalized on purpose
        "seats": seats,
        "seat_prices": seat_prices,                 # exact price of each seat
        "price_per_seat": round(amount / len(seats), 2),  # average (premium/regular mix)
        "amount": amount,
        "status": "CONFIRMED",
        "created_at": datetime.now(timezone.utc),
    }
    try:
        await db.bookings.insert_one(booking)
    except Exception:
        # compensation: give the seats back so they are not stuck as BOOKED
        await db.shows.update_one(
            {"_id": req.show_id},
            {
                "$set": {"seats.$[s].status": "AVAILABLE"},
                "$inc": {"available_count": len(seats)},
            },
            array_filters=[{"s.seat": {"$in": seats}}],
        )
        raise HTTPException(500, "Could not save the booking. Seats were released.")

    return booking


@app.get("/bookings/{booking_id}")
async def get_booking(booking_id: str):
    booking = await db.bookings.find_one({"_id": booking_id})
    if not booking:
        raise HTTPException(404, "Booking not found")
    return booking


@app.get("/users/{user_id}/bookings")
async def user_bookings(user_id: str):
    """Newest first. Uses index bookings_user_created."""
    return (
        await db.bookings.find({"user_id": user_id})
        .sort("created_at", -1)
        .to_list(50)
    )


# --------------------------------------------------------------- analytics
# The pipelines themselves live in app/pipelines.py (shared with the explain report).
@app.get("/analytics/revenue-per-movie")
async def revenue_per_movie():
    return await db.bookings.aggregate(pipelines.revenue_per_movie()).to_list(50)


@app.get("/analytics/occupancy")
async def occupancy(city: Optional[str] = None):
    """Booked / total seats per show. Optional ?city=Delhi."""
    return await db.shows.aggregate(pipelines.occupancy_per_show(city)).to_list(200)


@app.get("/analytics/top-movies")
async def top_movies(
    by: str = Query("tickets", pattern="^(tickets|revenue)$"),
    limit: int = Query(3, ge=1, le=20),
):
    """Ranked by tickets sold (default) or revenue."""
    return await db.bookings.aggregate(pipelines.top_movies(by, limit)).to_list(limit)


@app.get("/analytics/peak-hours")
async def peak_hours(tz: str = "UTC"):
    """Bookings, tickets and revenue by show start hour. tz example: Asia/Kolkata."""
    return await db.bookings.aggregate(pipelines.peak_hours(tz)).to_list(24)


# --------------------------------------------------------------- frontend (Part F)
FRONTEND_DIR = Path(__file__).resolve().parent.parent / "frontend"


@app.get("/", include_in_schema=False)
async def root():
    return RedirectResponse("/ui/")


app.mount("/ui", StaticFiles(directory=FRONTEND_DIR, html=True), name="ui")