"""Aggregation pipelines for CineBook analytics (Part D).

They live in one place so the API (app/main.py) and the explain() report
(scripts/explain_report.py) run exactly the same pipelines.

Efficiency rules used everywhere:
  * $match first, on indexed fields, so MongoDB reads as few documents as possible.
  * $project early, so big fields (like the seats array) are dropped before $group.
  * $group and $sort are BLOCKING stages: they must see all their input before they
    can output anything. They are cheap here because they run on already-filtered,
    already-slimmed documents (and $sort after $group sorts only a handful of rows).
"""


def revenue_per_movie():
    """Total booking amount and tickets per movie.
    No $lookup needed: each booking carries movie_id and movie_title (denormalized)."""
    return [
        {"$match": {"status": "CONFIRMED"}},                       # uses bookings_status_movie
        {"$project": {"movie_id": 1, "movie_title": 1, "amount": 1,
                      "n": {"$size": "$seats"}}},                  # drop the seats array early
        {"$group": {                                               # BLOCKING
            "_id": "$movie_id",
            "title": {"$first": "$movie_title"},
            "revenue": {"$sum": "$amount"},
            "tickets": {"$sum": "$n"},
        }},
        {"$sort": {"revenue": -1}},                                # BLOCKING, but only a few rows
    ]


def occupancy_per_show(city=None):
    """Booked seats / total seats for each show (optionally one city only)."""
    pipeline = []
    if city:
        pipeline.append({"$match": {"city": city}})                # uses shows_city_movie_start
    pipeline += [
        {"$project": {
            "movie_id": 1, "city": 1, "start_time": 1,
            "total": {"$size": "$seats"},
            "booked": {"$size": {"$filter": {
                "input": "$seats", "as": "s",
                "cond": {"$eq": ["$$s.status", "BOOKED"]},
            }}},
        }},
        {"$lookup": {"from": "movies", "localField": "movie_id",   # join uses movies _id index
                     "foreignField": "_id", "as": "movie"}},
        {"$set": {
            "title": {"$first": "$movie.title"},
            "occupancy_pct": {"$round": [
                {"$multiply": [{"$divide": ["$booked", "$total"]}, 100]}, 1]},
        }},
        {"$project": {"_id": 1, "title": 1, "city": 1, "start_time": 1,
                      "booked": 1, "total": 1, "occupancy_pct": 1}},
        {"$sort": {"occupancy_pct": -1, "start_time": 1}},         # BLOCKING
    ]
    return pipeline


def top_movies(by="tickets", limit=3):
    """Movies ranked by tickets sold or by revenue."""
    key = "tickets" if by == "tickets" else "revenue"
    return [
        {"$match": {"status": "CONFIRMED"}},
        {"$project": {"movie_id": 1, "movie_title": 1, "amount": 1,
                      "n": {"$size": "$seats"}}},
        {"$group": {                                               # BLOCKING
            "_id": "$movie_id",
            "title": {"$first": "$movie_title"},
            "revenue": {"$sum": "$amount"},
            "tickets": {"$sum": "$n"},
        }},
        {"$sort": {key: -1}},
        {"$limit": limit},                                         # $sort + $limit = top-k sort
    ]


def peak_hours(tz="UTC"):
    """Bookings, tickets and revenue grouped by the hour the show starts."""
    return [
        {"$match": {"status": "CONFIRMED"}},
        {"$project": {
            "hour": {"$hour": {"date": "$start_time", "timezone": tz}},
            "amount": 1,
            "n": {"$size": "$seats"},
        }},
        {"$group": {                                               # BLOCKING
            "_id": "$hour",
            "bookings": {"$sum": 1},
            "tickets": {"$sum": "$n"},
            "revenue": {"$sum": "$amount"},
        }},
        {"$project": {"_id": 0, "hour": "$_id", "bookings": 1,
                      "tickets": 1, "revenue": 1}},
        {"$sort": {"revenue": -1}},
    ]
