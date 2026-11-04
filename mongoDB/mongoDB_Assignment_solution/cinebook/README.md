Part A: Data modeling (15 pts)

1. Embed or reference?
Relationship	Decision	Why (simple words)
Screens inside theaters	Embed	A theater has only a few screens. You always need them together with the theater. They change rarely.
Seats inside shows	Embed	One show has about 50 seats, which is tiny. Putting them in the same document lets one update change a seat atomically. This is the heart of the project.
Bookings to shows	Reference (show_id)	Bookings grow forever. If you embedded them, the show document would keep growing. You also need to query bookings on their own, for example “my bookings”.
Bookings to users	Reference (user_id)	A user has unlimited bookings over time. Same reason.
Shows to movie and theater	Reference (movie_id, theater_id)	One movie has many shows. Copying the full movie into each show would repeat data.
2. Seat availability design (the most important decision)

Each show document has a seats array, and each seat has {seat, category, status}.

MongoDB guarantees that a write to one document is atomic. Two requests cannot change the same document at the same time, because one finishes before the other starts. So we write a conditional update: “set seat A1 to BOOKED only if A1 is still AVAILABLE”. The check and the change happen as one step, so no other request can sneak in between them. That is why no two users can ever get the same seat.

For several seats, the filter requires all of them to be AVAILABLE. If even one is taken, nothing matches and nothing changes, so the booking is all-or-nothing. We build this exact query in Part C.

A small refinement: add available_count to the show and update it with $inc in the same write. Then occupancy in Part D is cheap to compute. This is optional but it is a good industry touch.

3. Choice of _id
Collection	_id	Reason
movies, theaters, shows	Natural, readable string (MOV-DUNE2, THR-DEL-01, SHW-000512)	Given in the PDF, easy to debug, and used directly in API URLs.
bookings	App-generated string (BKG- plus a short uuid)	Customers see it on their ticket, so we do not want to expose a raw ObjectId.
users	USR-9032 style string	Same readable style as the rest.

The trade-off is that you must guarantee uniqueness yourself. MongoDB always enforces unique _id, so a duplicate insert simply fails. ObjectId would be generated automatically, but it is less readable.

4. Where we deliberately denormalize

On a booking we copy movie_title, theater_name, start_time, and price_per_seat, and we store amount.

Benefit: a ticket can be shown with one read and no joins. Revenue is also calculated from the price paid at that moment.
Trade-off: if the movie is renamed or prices change later, old bookings keep the old values. For a receipt that is correct, because history must not change. The cost is a little extra storage and the need to keep copies consistent if an old record is ever corrected.
We also copy city into each show, so the main browsing query can use one index.

Your final booking document will be:

json
{
  "_id": "BKG-8f2c1a",
  "show_id": "SHW-000512",
  "user_id": "USR-9032",
  "movie_id": "MOV-DUNE2",
  "movie_title": "Dune: Part Two",
  "theater_name": "Downtown Cineplex",
  "start_time": ISODate("2026-07-20T18:30:00Z"),
  "seats": ["A1", "A5"],
  "price_per_seat": 450,
  "amount": 900,
  "status": "CONFIRMED",
  "created_at": ISODate("2026-07-14T09:20:00Z")
}

Part A is now complete. When you write the README, copy the four sections above in your own words.

Reply “next” and I’ll do Part B: the full seed script, the $jsonSchema validation, and the indexes with the ESR rule explained. If you hit any error in Step 1, send me the message and I’ll fix it first.