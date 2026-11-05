```
1. Browse shows: Dune in Delhi from 10 Nov, sorted by time
  index under test: shows_city_movie_start
  BEFORE (no index): SORT > PROJECTION_SIMPLE > COLLSCAN
           docs examined=12  keys examined=0  returned=2  time=0 ms  in-memory sort: YES (in-memory SORT)
  AFTER  (with index): PROJECTION_SIMPLE > FETCH > IXSCAN(shows_city_movie_start)
           docs examined=2  keys examined=2  returned=2  time=1 ms  in-memory sort: no

2. A user's bookings, newest first
  index under test: bookings_user_created
  BEFORE (no index): SORT > COLLSCAN
           docs examined=80  keys examined=0  returned=22  time=0 ms  in-memory sort: YES (in-memory SORT)
  AFTER  (with index): FETCH > IXSCAN(bookings_user_created)
           docs examined=22  keys examined=22  returned=22  time=1 ms  in-memory sort: no

3. Revenue per movie (aggregation on bookings)
  index under test: bookings_status_movie
  BEFORE (no index): PROJECTION_DEFAULT > COLLSCAN
           docs examined=80  keys examined=0  returned=80  time=0 ms  in-memory sort: no
           later pipeline stages: $group, $sort
  AFTER  (with index): PROJECTION_DEFAULT > FETCH > IXSCAN(bookings_status_movie)
           docs examined=80  keys examined=80  returned=80  time=1 ms  in-memory sort: no
           later pipeline stages: $group, $sort

4. Occupancy per show in Delhi (aggregation on shows)
  index under test: shows_city_movie_start
  BEFORE (no index): PROJECTION_DEFAULT > COLLSCAN
           docs examined=12  keys examined=0  returned=4  time=0 ms  in-memory sort: no
           later pipeline stages: $lookup, $set, $project, $sort
  AFTER  (with index): PROJECTION_DEFAULT > FETCH > IXSCAN(shows_city_movie_start)
           docs examined=4  keys examined=4  returned=4  time=1 ms  in-memory sort: no
           later pipeline stages: $lookup, $set, $project, $sort

```
