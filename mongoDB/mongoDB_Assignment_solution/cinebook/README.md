# CineBook: Movie Booking with MongoDB Atlas, FastAPI and Kafka CDC

CineBook is a movie-ticket booking backend. It has a MongoDB Atlas data model, a FastAPI backend with
race-free seat booking, analytics built with the aggregation framework, a simple frontend, and a
change-data-capture (CDC) pipeline that streams booking changes from MongoDB to a Kafka topic on
Confluent Cloud.

## Contents

1. [Architecture](#1-architecture)
2. [Project structure](#2-project-structure)
3. [Setup and run](#3-setup-and-run)
4. [Part A: Data modeling](#part-a-data-modeling)
5. [Part B: Atlas setup, validation and indexes](#part-b-atlas-setup-validation-and-indexes)
6. [Part C: FastAPI backend and atomic booking](#part-c-fastapi-backend-and-atomic-booking)
7. [Part D: Aggregation and indexing](#part-d-aggregation-and-indexing)
8. [Part E: CDC to Kafka](#part-e-cdc-to-kafka)
9. [Part F: Frontend](#part-f-frontend)
10. [Part G: Bonus](#part-g-bonus)
11. [Screenshots and sample outputs](#screenshots-and-sample-outputs)
12. [Assumptions and limitations](#assumptions-and-limitations)

---

## 1. Architecture

```
BROWSER (simple frontend: frontend/index.html)
   | HTTP (fetch)
   v
FASTAPI BACKEND (Python, Motor)        app/main.py, app/holds.py, app/pipelines.py
   | reads / writes
   v
MONGODB ATLAS (M0)                     collections: movies, theaters, shows, bookings, users
   | change stream on the bookings collection
   v
CONFLUENT CLOUD
   MongoDB Atlas Source Connector (fully managed CDC)
   | publishes change events
   v
KAFKA TOPIC  cdc.cinebook.bookings
   |
   v
CONSUMER (cdc/consumer.py)  ->  prints events + live tickets-per-movie count
```

![Architecture diagram](documents/architecture.png)

| Layer | Technology |
|---|---|
| Database | MongoDB Atlas free tier (M0), MongoDB Compass |
| Backend | Python 3, FastAPI, Uvicorn, Motor (async driver) |
| Scripts | PyMongo (seed, validation, indexes, explain report) |
| Frontend | Plain HTML + JavaScript (`fetch`), served by FastAPI |
| CDC | Confluent Cloud: MongoDB Atlas Source connector, Kafka topic, `confluent-kafka` consumer |

---

## 2. Project structure

```
cinebook/
├── .env                      # real secrets (never committed)
├── .env.example              # placeholders only (committed)
├── .gitignore
├── README.md
├── explain_report.md         # output of scripts/explain_report.py
├── app/
│   ├── __init__.py
│   ├── db.py                 # Motor connection
│   ├── main.py               # REST API (Parts C, D, F)
│   ├── pipelines.py          # aggregation pipelines (Part D)
│   └── holds.py              # seat holds + transaction booking (Part G)
├── scripts/
│   ├── apply_validation.py   # collections + $jsonSchema validation
│   ├── seed_data.py          # movies, theaters, shows, users
│   ├── create_indexes.py     # ESR indexes
│   ├── create_hold_indexes.py# bonus indexes (partial + TTL)
│   ├── generate_bookings.py  # demo bookings through the API
│   ├── explain_report.py     # explain() before/after indexing
│   ├── test_validation.py    # proves validation rejects bad documents
│   ├── test_concurrency.py   # proves no double booking
│   └── test_bonus.py         # tests holds, expiry and transactions
├── cdc/
│   ├── connector.json        # connector configuration (placeholders only)
│   └── consumer.py           # Kafka consumer
├── frontend/
│   └── index.html
└── documents/
    ├── architecture.png
    └── screenshots/
```

---

## 3. Setup and run

### 3.1 Prerequisites

- Python 3.10 or newer
- A MongoDB Atlas free (M0) cluster and MongoDB Compass
- A Confluent Cloud account (only needed for Part E)

### 3.2 Install

```bash
python3 -m venv venv
source venv/bin/activate
python3 -m pip install fastapi uvicorn motor pymongo python-dotenv confluent-kafka pydantic httpx
```

### 3.3 Environment variables

Copy `.env.example` to `.env` and fill in your own values. Real secrets are never committed.

| Variable | Meaning |
|---|---|
| `MONGODB_URI` | Atlas SRV connection string, for example `mongodb+srv://USER:PASSWORD@CLUSTER.mongodb.net` |
| `MONGODB_DB` | Database name, `cinebook` |
| `KAFKA_BOOTSTRAP` | Confluent bootstrap server (only for the consumer) |
| `KAFKA_API_KEY` | Confluent Kafka API key (only for the consumer) |
| `KAFKA_API_SECRET` | Confluent Kafka API secret (only for the consumer) |

Optional settings for the bonus (Part G): `HOLD_MINUTES` (default 5) and `SWEEP_SECONDS` (default 15).

### 3.4 MongoDB Atlas

1. Create an M0 cluster.
2. Create a database user `cinebook_app` with the roles `readWrite` and `dbAdmin` on the `cinebook`
   database only (`readWrite` for the API, `dbAdmin` for validation and index scripts).
3. In Network Access, allow your own IP address.
4. Connect Compass with the same connection string.

### 3.5 Create the data (run in this order, from the project root)

```bash
python3 scripts/apply_validation.py    # 1. collections + validation rules
python3 scripts/seed_data.py           # 2. seed data (also clears bookings)
python3 scripts/create_indexes.py      # 3. indexes
python3 scripts/create_hold_indexes.py # 4. bonus indexes (Part G)
```

Validation goes first so the rules already apply when the seed data is inserted.

### 3.6 Run the API and the frontend

```bash
uvicorn app.main:app --reload
```

- Interactive API docs: http://127.0.0.1:8000/docs
- Frontend: http://127.0.0.1:8000/ (redirects to `/ui/`)

### 3.7 Demo data and checks

```bash
python3 scripts/generate_bookings.py   # ~80 demo bookings made through the API
python3 scripts/explain_report.py      # explain() before/after, saved to explain_report.md
python3 scripts/test_concurrency.py    # proves no double booking
python3 scripts/test_validation.py     # proves bad documents are rejected
```

The bonus test needs the server started with a short hold time:

```bash
HOLD_MINUTES=0.2 SWEEP_SECONDS=5 uvicorn app.main:app --reload
python3 scripts/test_bonus.py
```

To reset the data, run `python3 scripts/seed_data.py` again.

### 3.8 CDC to Kafka

Full steps are in [Part E](#part-e-cdc-to-kafka). In short: create the Kafka cluster and API key in Confluent
Cloud, create the Atlas Source connector (values from `cdc/connector.json`), put the Kafka values in `.env`,
then run `python3 cdc/consumer.py`.

---

## Part A: Data modeling

### Embed or reference?

| Relationship | Decision | Why |
|---|---|---|
| Screens inside theaters | Embed | A theater has only a few screens, they are always read with the theater, and they rarely change. |
| Seats inside shows | Embed | One show has about 50 seats, which is tiny. Keeping them in the same document lets one update change a seat atomically. This is the core of the design. |
| Bookings to shows | Reference (`show_id`) | Bookings grow forever. Embedding them would make the show document grow without limit, and bookings must be queried on their own (for example "my bookings"). |
| Bookings to users | Reference (`user_id`) | A user has unlimited bookings over time. Same reason. |
| Shows to movie and theater | Reference (`movie_id`, `theater_id`) | One movie has many shows. Copying the full movie into each show would repeat data. |

### Seat availability design

Each show document has a `seats` array, and each seat is `{seat, category, status}` with status
`AVAILABLE`, `HELD` or `BOOKED`. The show also keeps `available_count`, updated with `$inc` in the same
write, so occupancy is cheap to compute.

MongoDB guarantees that a write to a single document is atomic: two requests cannot change the same
document at the same time. A booking is therefore a conditional update: "set seat A1 to BOOKED only if A1
is still AVAILABLE". The check and the change happen as one step, so no other request can slip in between.
That is why no two users can ever get the same seat.

For several seats, the filter requires all of them to be AVAILABLE. If even one is taken, nothing matches
and nothing changes, so the booking is all-or-nothing (implemented in Part C).

### Choice of `_id`

| Collection | `_id` | Reason |
|---|---|---|
| movies, theaters, shows | Natural readable string (`MOV-DUNE2`, `THR-DEL-01`, `SHW-000512`) | Given in the assignment, easy to debug, used directly in API URLs. |
| bookings | App-generated string (`BKG-` + short uuid) | Customers see it on their ticket, so no raw ObjectId is exposed. |
| users | String (`USR-1001`) | Same readable style. |

Trade-off: with natural keys the application must guarantee uniqueness. MongoDB still enforces a unique
`_id`, so a duplicate insert fails instead of silently overwriting. An ObjectId would be generated
automatically but is less readable.

### Deliberate denormalization

A booking stores `movie_id`, `movie_title`, `theater_name`, `start_time`, `seat_prices`, `price_per_seat`
and `amount`. A show stores `city`.

- Benefit: a ticket is shown with one read and no join, revenue uses the price actually paid, and the
  analytics need no `$lookup`. Carrying `city` on the show lets the main browsing query use one index.
- Trade-off: if a movie is renamed or prices change later, old bookings keep the old values. For a receipt
  that is correct, because history must not change. The cost is some extra storage and the need to correct
  copies by hand if a record was wrong.
- `amount` is the exact total. `seat_prices` holds the exact price of each seat. `price_per_seat` is the
  average, because premium and regular seats cost different amounts.

Final booking document:

```json
{
  "_id": "BKG-1a2b3c4d",
  "show_id": "SHW-000501",
  "user_id": "USR-1001",
  "movie_id": "MOV-DUNE2",
  "movie_title": "Dune: Part Two",
  "theater_name": "Downtown Cineplex",
  "start_time": "ISODate(2026-11-10T18:30:00Z)",
  "seats": ["A1", "A5"],
  "seat_prices": { "A1": 450, "A5": 450 },
  "price_per_seat": 450.0,
  "amount": 900,
  "status": "CONFIRMED",
  "created_at": "ISODate(2026-11-05T09:20:00Z)"
}
```

---

## Part B: Atlas setup, validation and indexes

### Collections and seed data

Collections: `movies`, `theaters`, `shows`, `bookings`, `users`.

Seed data (`scripts/seed_data.py`): 4 movies, 3 theaters in 3 cities (Delhi, Mumbai, Bengaluru), 12 shows
with 50 seats each (rows A to E, 10 per row, rows A-B premium), and 4 users. `start_time` is stored as a
real BSON date, not a string. `bookings` starts empty and is filled by the API.

### Schema validation (`scripts/apply_validation.py`)

`$jsonSchema` validation is applied to `shows` and `bookings` with `validationLevel: strict`. The default
action is `error`; running the script with the argument `warn` applies `warn` instead.

| Collection | Rules |
|---|---|
| `shows` | Required: `_id`, `movie_id`, `theater_id`, `screen_id`, `city`, `start_time` (date), `prices` (object with numeric `PREMIUM` and `REGULAR`), `available_count` (integer, at least 0), `seats` (non-empty array). Every seat needs `seat` (string), `category` (enum `PREMIUM`/`REGULAR`) and `status` (enum `AVAILABLE`/`HELD`/`BOOKED`). |
| `bookings` | Required: `_id`, `show_id`, `user_id`, `movie_id`, `movie_title`, `seats` (non-empty array of unique strings), `price_per_seat` and `amount` (numbers, at least 0), `status` (enum `CONFIRMED`/`HELD`/`CANCELLED`), `created_at` (date). |

`scripts/test_validation.py` tries to insert an invalid booking and the database rejects it with
"Document failed validation".

### Indexes (`scripts/create_indexes.py`)

Compound indexes follow the ESR rule: Equality fields first, then the Sort field, then Range fields.
Example: browsing shows filters `city` and `movie_id` by equality and uses `start_time` for both the range
and the sort, so the index is `{city, movie_id, start_time}` and MongoDB needs no in-memory sort.

| Index | Query it serves |
|---|---|
| `shows: {city, movie_id, start_time}` | `GET /movies/{id}/shows` filtered by city and date, sorted by time |
| `shows: {theater_id, start_time}` | Shows of one theater in time order |
| `movies: {cities, language}` | `GET /movies` filtered by city and language |
| `movies: {genres}` | `GET /movies` filtered by genre |
| `bookings: {user_id, created_at -1}` | `GET /users/{id}/bookings`, newest first |
| `bookings: {show_id, status}` | Bookings of one show |
| `bookings: {status, movie_id}` | Revenue, top-movie and peak-hour analytics |

Indexes are for query speed, not uniqueness. Only `_id` is unique.

---

## Part C: FastAPI backend and atomic booking

### API reference

| Method and path | Input | Output |
|---|---|---|
| `GET /health` | none | `{"status": "ok"}` |
| `GET /movies` | optional query: `city`, `language`, `genre` | List of movies |
| `GET /movies/{movie_id}/shows` | optional query: `city`, `date` (`YYYY-MM-DD`, UTC) | Shows of the movie sorted by `start_time`, without the seats array. 404 if the movie is unknown, 400 for a bad date. |
| `GET /shows/{show_id}/seats` | none | `{show_id, available_count, prices, seats[]}` |
| `POST /bookings` | body `{user_id, show_id, seats[1..10]}` | 201 with the booking. 409 if any seat is taken. 400 for duplicate or unknown seats. 404 for unknown user or show. |
| `GET /bookings/{booking_id}` | none | The booking, or 404 |
| `GET /users/{user_id}/bookings` | none | The user's bookings, newest first (up to 50) |
| `GET /analytics/revenue-per-movie` | none | Revenue and tickets per movie |
| `GET /analytics/occupancy` | optional query: `city` | Booked, total and occupancy percentage per show |
| `GET /analytics/top-movies` | optional query: `by` (`tickets` or `revenue`), `limit` | Movies ranked by the chosen measure |
| `GET /analytics/peak-hours` | optional query: `tz` (default `UTC`) | Bookings, tickets and revenue per show start hour |
| `POST /holds` | body `{user_id, show_id, seats[]}` | 201 with a `HELD` booking and `expires_at` (Part G) |
| `POST /holds/{booking_id}/confirm` | body `{user_id}` | The `CONFIRMED` booking (Part G) |
| `POST /bookings/transactional` | body `{user_id, show_id, seats[]}` | 201 with the booking, or 409 (Part G) |

Successful booking request and response:

```json
POST /bookings
{ "user_id": "USR-1001", "show_id": "SHW-000501", "seats": ["A1", "A5"] }

201 Created
{ "_id": "BKG-1a2b3c4d", "show_id": "SHW-000501", "user_id": "USR-1001", "movie_title": "Dune: Part Two",
  "seats": ["A1", "A5"], "amount": 900, "status": "CONFIRMED", "...": "..." }
```

Rejected double booking:

```json
409 Conflict
{ "detail": { "message": "Some seats are no longer available. Nothing was booked.",
              "unavailable": ["A1", "A5"] } }
```

### Concurrency safety

POST /bookings reserves seats with a single conditional update on the show document.
The filter requires every requested seat to be AVAILABLE (one `$elemMatch` per seat inside `$and`);
the update sets those seats to BOOKED and decrements `available_count` in the same operation.

MongoDB applies writes to a single document atomically, so two concurrent requests are serialized: the first
one flips the seats, and the second one finds them BOOKED, matches no document (`modified_count == 0`), and
receives HTTP 409. There is no gap between the check and the change, so a seat can never be sold twice.

If only some of the requested seats are available, the filter matches nothing, so NO seat is changed and NO
booking document is created. The user gets a 409 listing the unavailable seats.

If saving the booking document fails after the seats were reserved, the code releases the seats again
(compensation). Limitation: a hard server crash between the two writes could leave seats booked without a
booking; the multi-document transaction endpoint (Part G) removes that window.

Tested with `scripts/test_concurrency.py`: 10 simultaneous requests for one seat gave exactly one success;
two overlapping multi-seat requests gave exactly one success.

---

## Part D: Aggregation and indexing

Pipelines live in `app/pipelines.py` and are exposed as `GET /analytics/...`.

| Analytics | Pipeline |
|---|---|
| Revenue per movie | `$match` CONFIRMED, `$project`, `$group` by movie, `$sort` by revenue. No `$lookup` is needed because bookings carry `movie_id` and `movie_title` (denormalized). |
| Occupancy per show | Booked seats (`$filter` on the seats array) divided by total seats; `$lookup` adds the movie title. |
| Top movies | Same grouping, then `$sort` and `$limit`, ranked by tickets or revenue. |
| Peak time slots | `$hour` of `start_time`, grouped by hour (bookings, tickets, revenue). |

Efficiency: `$match` comes first so an index is used, and `$project` drops the seats array before `$group`.
`$group` and `$sort` are blocking stages (they need all their input before producing output), but they run
on small, already-filtered data.

### explain(executionStats): before and after indexing

Produced by `scripts/explain_report.py` (also saved in `explain_report.md`). For each query it drops the
index, runs `explain`, re-creates the index and runs `explain` again.

```
[paste the output of scripts/explain_report.py here]
```

Result: queries 1 and 2 changed from COLLSCAN with an in-memory SORT to IXSCAN with no SORT; the
aggregations changed from COLLSCAN to IXSCAN on the `$match`. The dataset is small, so timings are similar,
but the number of documents examined dropped to roughly the number returned.

---

## Part E: CDC to Kafka

### Setup

Path used: the fully managed MongoDB Atlas Source connector on Confluent Cloud (no local Kafka Connect).

1. Atlas: Network Access allows the connector (`0.0.0.0/0` for the test only, removed afterwards). A
   dedicated user `cinebook_cdc` has the `readWrite` role on the `cinebook` database only.
2. Confluent Cloud: a Basic Kafka cluster and an API key. The bootstrap server, key and secret go in `.env`.
3. The connector is created in the Confluent Cloud UI. `cdc/connector.json` is the equivalent configuration
   with placeholders only (secrets are never committed). It watches `cinebook.bookings` and publishes to the
   topic `cdc.cinebook.bookings` (topic prefix + database + collection).
4. `python3 cdc/consumer.py` reads the topic and prints each change event.

Connector configuration (placeholders):

```json
{
  "connector.class": "MongoDbAtlasSource",
  "name": "cinebook-bookings-source",
  "kafka.auth.mode": "KAFKA_API_KEY",
  "kafka.api.key": "{{KAFKA_API_KEY}}",
  "kafka.api.secret": "{{KAFKA_API_SECRET}}",
  "connection.host": "{{CLUSTER}}.mongodb.net",
  "connection.user": "{{ATLAS_DB_USER}}",
  "connection.password": "{{ATLAS_DB_PASSWORD}}",
  "database": "cinebook",
  "collection": "bookings",
  "topic.prefix": "cdc",
  "output.data.format": "JSON",
  "startup.mode": "copy_existing",
  "change.stream.full.document": "updateLookup",
  "poll.await.time.ms": "5000",
  "poll.max.batch.size": "100",
  "tasks.max": "1"
}
```

`startup.mode: copy_existing` also publishes the bookings that already existed. `updateLookup` makes update
events carry the full booking document.

### Change streams and the event shape

MongoDB keeps an ordered log of changes (the oplog). A change stream lets a client subscribe to it and
receive an event for every insert, update, replace and delete.

- `operationType`: insert, update, replace or delete
- `fullDocument`: the booking document (for updates this needs `change.stream.full.document=updateLookup`)
- `documentKey`: the `_id` of the changed document
- `ns`: database and collection
- `_id`: the resume token, a bookmark. If the connector stops, it resumes from the last token instead of
  missing or restarting everything.

Shape of an event (illustrative; the sample from the real topic is pasted below):

```json
{
  "_id": { "_data": "8267..." },
  "operationType": "insert",
  "ns": { "db": "cinebook", "coll": "bookings" },
  "documentKey": { "_id": "BKG-1a2b3c4d" },
  "fullDocument": { "_id": "BKG-1a2b3c4d", "user_id": "USR-1001", "seats": ["A1", "A5"], "status": "CONFIRMED" }
}
```

### Delivery guarantee and use case

Delivery is at-least-once. After a failure or restart the same event can be delivered again (this also
happens with `startup.mode=copy_existing`), so consumers must be idempotent. Our consumer ignores a booking
it has already counted.

Use case: feeding analytics or a warehouse. Booking events stream into Kafka, and other systems (a
dashboard, a warehouse loader, a notification service) consume them without querying the production
database. Our consumer keeps a live tickets-per-movie count (bonus).

### Sample events

```
[paste: a sample insert event and a sample update event from the topic, and the consumer output]
```

---

## Part F: Frontend

Plain HTML + JavaScript (`frontend/index.html`), served by FastAPI at `/ui/`. Flow: choose a city, pick a
movie (`GET /movies`), pick a show (`GET /movies/{id}/shows`), choose seats (`GET /shows/{id}/seats`) and
book (`POST /bookings`). A 409 response is shown as "Seat already taken" with the unavailable seats, and the
seat map refreshes. A demo button books the selected seats as another user first, so the rejection can be
shown on demand.

---

## Part G: Bonus

### Seat hold with expiry

`POST /holds` marks the seats HELD with the same atomic conditional update as Part C and creates a booking
with status HELD and an `expires_at` time (`HOLD_MINUTES`, default 5). `POST /holds/{id}/confirm` turns it
into CONFIRMED and the seats into BOOKED.

Expired holds are released by a background sweep (every `SWEEP_SECONDS`) that cancels the booking and sets
its seats back to AVAILABLE. A TTL index alone cannot do this, because it can only delete a document; it
cannot update the seats array inside the show. A TTL index on `purge_at` is still used to delete old
cancelled holds a day later; only cancelled holds get this field, so confirmed bookings are never deleted.

Confirm and the sweep both claim the booking with a conditional update on `status = HELD`, so only one of
them can win. A partial index on `expires_at` (only HELD bookings) serves the sweep query.

| Index | Query it serves |
|---|---|
| `bookings: {expires_at}` (partial, status = HELD) | The sweep: find held bookings that have expired |
| `bookings: {purge_at}` (TTL, expireAfterSeconds 0) | MongoDB deletes cancelled holds automatically |

### Multi-seat transaction

`POST /bookings/transactional` reserves each seat and inserts the booking inside one transaction
(`session.with_transaction`). If any seat is taken, the whole transaction rolls back.

| | Single conditional update (Part C) | Multi-document transaction (Part G) |
|---|---|---|
| How it works | One `update_one`; the filter requires all seats AVAILABLE | One update per seat, then the booking insert, all in one transaction |
| Atomic across | One document (the show) | Several documents and collections |
| Cost | One round trip, nothing to retry | More round trips and overhead; write conflicts are retried |
| Limits | The booking insert is a separate write, so a crash in between needs a compensation step | Transactions have a time limit and use more server resources |
| Best when | Everything that must change together is in one document (our design) | The data that must change together lives in different documents |

Our seats and `available_count` live in one document, so the single update is the better tool and Part C
uses it. The transaction endpoint shows how to get the same all-or-nothing result when atomicity must span
documents, and it closes the small crash window described in Part C.

### Live CDC aggregate

`cdc/consumer.py` keeps a real-time tickets-per-movie count from the booking status (CONFIRMED adds,
CANCELLED removes, HELD is ignored) and ignores duplicate deliveries.

```
[paste: test_bonus.py output, a "[sweep] released ..." log line, and the consumer output]
```

---

## Screenshots and sample outputs

Add the images to `documents/screenshots/` (or delete a line if you do not include it).

| What it shows | Image |
|---|---|
| Collections and seed data in Compass | ![collections](documents/screenshots/01_collections.png) |
| A show document with a Date `start_time` and the seats array | ![show document](documents/screenshots/02_show_document.png) |
| Indexes of the `shows` collection | ![indexes](documents/screenshots/03_indexes.png) |
| Validation rules of `bookings` and a rejected invalid document | ![validation](documents/screenshots/04_validation.png) |
| Successful booking (HTTP 201) | ![booking ok](documents/screenshots/05_booking_201.png) |
| Rejected double booking (HTTP 409) | ![booking rejected](documents/screenshots/06_booking_409.png) |
| Concurrency test output | ![concurrency](documents/screenshots/07_concurrency_test.png) |
| Analytics results (4 endpoints) | ![analytics](documents/screenshots/08_analytics.png) |
| explain() before and after | ![explain](documents/screenshots/09_explain.png) |
| Frontend: seat map, confirmation, rejection | ![frontend](documents/screenshots/10_frontend.png) |
| Connector running and messages in the topic | ![cdc topic](documents/screenshots/11_cdc_topic.png) |
| Consumer output | ![consumer](documents/screenshots/12_consumer.png) |
| Bonus tests output | ![bonus](documents/screenshots/13_bonus_tests.png) |

---

## Assumptions and limitations

- Payment is simulated: confirming a hold stands in for paying.
- There is no login. Four seeded users stand in for authentication.
- Times are stored and compared in UTC. City, language and genre filters are case-sensitive and must match
  the stored value (for example `Delhi`).
- `price_per_seat` on a booking is the average of the seat prices; the exact price of each seat is in
  `seat_prices`.
- In `POST /bookings` the seat reservation and the booking insert are two separate writes, so a hard crash
  between them could leave seats booked without a booking (a compensation step covers normal errors). The
  transaction endpoint avoids this.
- A hold can stay HELD up to `SWEEP_SECONDS` longer than its `expires_at`, because release is done by the
  sweep. `POST /holds` also runs the sweep first, and confirming an expired hold is always rejected.
- CDC delivery is at-least-once, so duplicate events are possible.
- The Atlas free tier limits storage and throughput (about 100 operations per second), so heavy concurrent
  tests may run a little slower.
- `0.0.0.0/0` in Atlas Network Access was used for the CDC test only. In production, use Confluent's
  published connector egress IPs.
- Cloud resources (the connector and the Kafka cluster) are deleted after testing to save trial credits.