# VoltRoute Real-Time Charging Pipeline (Kafka + ksqlDB on Confluent Cloud)

## 1. Overview

VoltRoute is a (fictional) operator of a nationwide network of electric-vehicle charging stations. This project builds a real-time streaming pipeline for it on **Confluent Cloud**:

1. Python producers generate mock **station reference data** and **charging-session events** (start and stop) and publish them to Kafka topics as **Avro**, with schemas registered in **Schema Registry**.
2. **ksqlDB** matches each session start with its stop (windowed stream-stream join), **enriches** completed sessions with station data (stream-table join), and computes live metrics (energy, session count, cost) per city and per station using **tumbling** and **hopping** windows.
3. A **consumer group** (`billing_consumer`) reads the enriched sessions, demonstrating partition assignment, scaling, rebalancing and manual offset commits.
4. A **schema evolution** demo adds a backward-compatible field to `session_start`.
5. (Bonus) A **Kafka Streams** application reproduces the hourly per-city energy aggregation.

![Architecture diagram](docs/architecture.png)

*(A PDF copy is in `docs/architecture.pdf`.)*

### Project structure

```
voltroute-kafka/
├── README.md
├── requirements.txt
├── .env.example            # placeholders only
├── .gitignore              # ignores .env and venv/
├── schemas/
│   ├── charging_stations.avsc
│   ├── session_start_v1.avsc
│   ├── session_start_v2.avsc
│   └── session_stop.avsc
├── src/
│   ├── common.py
│   ├── check_connection.py
│   ├── stations_producer.py
│   ├── session_producer.py
│   ├── schema_demo_consumer.py
│   ├── schema_compat_check.py
│   └── billing_consumer.py
├── ksql/
│   └── voltroute_pipeline.sql
├── kstreams/
│   ├── pom.xml
│   └── src/main/java/com/voltroute/CityEnergyApp.java
└── docs/
    ├── architecture.png
    ├── architecture.pdf
    └── evidence/           # screenshots and captured output
```

---

## 2. Setup

### 2.1 Confluent Cloud resources

Everything runs on Confluent Cloud (no local broker, ZooKeeper or Schema Registry). Resources created:

| Resource | Name / setting |
|---|---|
| Environment | `voltroute-env` (Stream Governance package: Essentials) |
| Kafka cluster | `voltroute-cluster`, **Basic**, AWS `us-east-1` |
| Cluster API key | Global access, used by producers and consumers |
| Schema Registry | Endpoint of `voltroute-env`, with its own API key (separate from the cluster key) |
| ksqlDB cluster | `voltroute-ksql`, smallest size offered in the console (4 CSU) |

The ksqlDB cluster was created only for Part E and deleted afterwards to save credits (topics and data remain).

### 2.2 Python setup

Python 3 on Ubuntu:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

(`requirements.txt` contains `confluent-kafka[avro,schemaregistry]`, `fastavro` and `python-dotenv`.)

### 2.3 Configuration (`.env`)

Secrets are never committed. Copy `.env.example` to `.env` and fill in your own values. The variable **names** are:

```
BOOTSTRAP_SERVERS=
KAFKA_API_KEY=
KAFKA_API_SECRET=
SR_URL=
SR_API_KEY=
SR_API_SECRET=
```

- `BOOTSTRAP_SERVERS`: host and port of the Kafka cluster (without `SASL_SSL://`).
- `KAFKA_API_KEY` / `KAFKA_API_SECRET`: cluster API key pair.
- `SR_URL`: Schema Registry endpoint (starts with `https://`).
- `SR_API_KEY` / `SR_API_SECRET`: Schema Registry API key pair (a different pair from the cluster key).

### 2.4 Test the connection

Run from the project root with the virtual environment active:

```bash
python src/check_connection.py
```

Expected: `Kafka OK. Topics: [...]` and `Schema Registry OK. Subjects: [...]`.

---

## 3. Part A - Topic design

| Topic | Partitions | Key | cleanup.policy |
|---|---|---|---|
| `charging_stations` | 6 | `station_id` | `compact` |
| `session_start` | 6 | `session_id` | `delete` (default) |
| `session_stop` | 6 | `session_id` | `delete` (default) |

**Partitions.** All three topics have 6 partitions. Six allows up to six consumer instances in one group (a group cannot have more active members than partitions), leaves room to scale, and divides evenly across 1, 2, 3 or 6 consumers, while staying small enough to avoid needless broker overhead. `session_start` and `session_stop` have the same count so records with the same `session_id` land on the same partition number, which a windowed stream-stream join requires. `charging_stations` also has 6 so the re-keyed session stream can be joined to it in E.3.

**Keys.** `charging_stations` is keyed by `station_id`; `session_start` and `session_stop` are keyed by `session_id`. A key is hashed to choose the partition, so all events for one session go to one partition and are read in order (start before stop). For joins, ksqlDB can only match records whose keys are equal and which sit on the same partition number, so correct keying is what makes the joins possible.

**Cleanup policy.** `charging_stations` uses `cleanup.policy=compact` because it is reference data where only the latest state per station matters. Compaction keeps the newest record per `station_id` indefinitely, so a consumer or ksqlDB table that reads the topic from the beginning always rebuilds the full current state, and re-running the producer upserts instead of duplicating. A delete policy would eventually discard stations that rarely change. The event topics use `delete` because each event is an independent fact that is only needed for a limited time.

**Durability on a self-managed cluster (replication factor and min.insync.replicas).** I would use `replication.factor=3` and `min.insync.replicas=2`, with producers using `acks=all`, and `unclean.leader.election.enable=false`. With three copies, one broker can fail and writes are still accepted, because two in-sync replicas remain to satisfy min ISR. `acks=all` means a write is only acknowledged once at least two replicas have it, so an acknowledged record survives the loss of one broker. If two replicas were lost, producers would receive errors rather than silently risking data loss. On Confluent Cloud the replication factor is managed by Confluent, so I configured only partitions, keys and cleanup policy.

Evidence: topic Configuration tab screenshots in `docs/evidence/` (see the evidence index at the end).

---

## 4. How to run (in order)

All commands run from the project root with `source venv/bin/activate`. The `| tee` part saves the output as evidence; it is optional.

**1. Create the three topics** in the Confluent Cloud console (Part A table above).

**2. Stations producer** (run first; it must finish before the session producer):

```bash
python src/stations_producer.py 2>&1 | tee docs/evidence/02-stations-producer-output.txt
```

**3. Session producer:**

```bash
python src/session_producer.py --sessions 400 2>&1 | tee docs/evidence/03-session-producer-output.txt
```

Re-run the stations producer once to demonstrate upsert behaviour:

```bash
python src/stations_producer.py 2>&1 | tee docs/evidence/07-stations-rerun-output.txt
```

**4. Schema evolution (Part C)**, three terminals:

```bash
# Terminal 1: v1 consumer, leave running
python -u src/schema_demo_consumer.py --reader v1 2>&1 | tee docs/evidence/09-v1-consumer.txt
# Terminal 2: produce v2 events
python src/session_producer.py --sessions 40 --start-id 401 --schema-version 2 2>&1 | tee docs/evidence/10-v2-producer-output.txt
# Terminal 3: v2 consumer
python -u src/schema_demo_consumer.py --reader v2 2>&1 | tee docs/evidence/11-v2-consumer.txt
# Any terminal: versions and compatibility tests
python src/schema_compat_check.py 2>&1 | tee docs/evidence/12-schema-versions-after.txt
python src/schema_compat_check.py test 2>&1 | tee docs/evidence/13-compat-test.txt
```

**5. ksqlDB (Part E):** create the ksqlDB cluster, set `auto.offset.reset` to `earliest`, then run the statements in `ksql/voltroute_pipeline.sql` **one at a time, in order**, capturing the check queries. Delete the ksqlDB cluster afterwards.

**6. Consumer group (Part D)**, three terminals, a new group name for every demo run:

```bash
python -u src/billing_consumer.py --topic enriched_sessions --name A --group billing_demo1 --process-ms 1000 2>&1 | tee docs/evidence/20-consumer-A.txt
python -u src/billing_consumer.py --topic enriched_sessions --name B --group billing_demo1 --process-ms 1000 2>&1 | tee docs/evidence/21-consumer-B.txt
python -u src/billing_consumer.py --topic enriched_sessions --name C --group billing_demo1 --process-ms 1000 2>&1 | tee docs/evidence/22-consumer-C.txt
```

(`--topic session_start` can be used instead if ksqlDB output is not available; city and cost then print as `None`.)

**7. Optional, Kafka Streams bonus** (create the topic `city_energy_streams` with 6 partitions first):

```bash
cd kstreams
set -a; source ../.env; set +a
mvn -q compile exec:java -Dexec.mainClass=com.voltroute.CityEnergyApp 2>&1 | tee ../docs/evidence/50-kstreams-run.txt
```

---

## 5. Part B - Producers and Avro

**Schemas.** The four schema files in `schemas/` are the exact schemas from the assignment (`session_start_v2.avsc` is v1 plus `payment_method`). Subjects registered in Schema Registry: `charging_stations-value`, `session_start-value` (versions 1 and 2) and `session_stop-value`.

**Stations producer (`src/stations_producer.py`).** Generates 16 stations across 5 cities (Delhi, Mumbai, Bengaluru, Hyderabad, Pune), 14 ACTIVE and 2 in MAINTENANCE, with `max_power_kw` in {50, 150, 350} and tariffs between 12 and 22. Generation uses a fixed random seed, so every run produces identical records and re-running **upserts** instead of creating new stations. Records are keyed by `station_id` and written with a record timestamp 2 days in the past (explained in section 8, E.3).

**Session producer (`src/session_producer.py`).** Builds a simulated 10-hour day of sessions up front. Each session gets a `start_time` somewhere in that period and a duration of 10 to 90 minutes, so `stop_time = start_time + duration`. Only ACTIVE stations are used, `connector_id` is within the station's `num_connectors`, `end_soc_pct` is always higher than `start_soc_pct`, and `energy_kwh` (5 to 60) depends on duration and the station's power. All events are sorted by event time and sent in that order with a short real delay (a time-compressed replay). About 8% of starts are intentionally left without a matching stop.

**Run result.** `python src/session_producer.py --sessions 400` sent **763 events for 400 sessions; 37 starts have no stop** (9.25%, inside the 5 to 10% target).

**Partitioner.** All producers use `partitioner = murmur2_random`. The Python library (librdkafka) defaults to CRC32, but Java clients and ksqlDB hash keys with murmur2. Using murmur2 in Python keeps the same key on the same partition number everywhere, which the joins depend on.

**Notes.**
- Compaction is asynchronous, so after a re-run the old copies of a station record may still be visible in the log for a while. What compaction guarantees is that the latest value per key is kept. The ksqlDB table in Part E shows exactly 16 rows, which is the real proof of upsert semantics.
- The `%4|...GETPID` and `%6|...GETSUBSCRIPTIONS` lines in the producer output are harmless librdkafka log messages (an idempotence handshake retry and telemetry info), not errors.

Evidence: producer outputs, the topic Messages tabs, and the Schema Registry subjects screenshot are in `docs/evidence/`.

---

## 6. Part C - Schema evolution proof

**Compatibility mode:** `BACKWARD` (set explicitly on `session_start-value` by `src/schema_compat_check.py`).

**What BACKWARD permits and who upgrades first.** Under BACKWARD compatibility a consumer that uses the new schema must be able to read data written with the previous schema. That permits adding fields that have a default value and deleting fields. Because of this guarantee, **consumers are upgraded first**: a v2 consumer can read both old v1 records and new v2 records. Only after all consumers understand v2 should producers start writing v2.

**Evolution performed.** I added `payment_method` (string, default `UNKNOWN`) to `session_start`. Schema Registry accepted it as version 2. While a v1 consumer kept running, I produced v2 events (sessions `SESS-000401` and up); the v1 consumer continued without errors and ignored the new field. A v2 consumer read the new field on new records (`APP_WALLET`, `CREDIT_CARD`, `RFID_CARD`) and received the default `UNKNOWN` on old v1 records.

| Version | Fields | Registered by |
|---|---|---|
| 1 | session_id, station_id, connector_id, vehicle_id, user_id, start_time, start_soc_pct | first run of `session_producer.py` (v1) |
| 2 | version 1 + `payment_method` (default `UNKNOWN`) | `session_producer.py --schema-version 2` |

Before/after output: `docs/evidence/09-v1-consumer.txt`, `10-v2-producer-output.txt`, `11-v2-consumer.txt`, `12-schema-versions-after.txt` and the Schema Registry version history screenshot.

**Compatibility test results** (`python src/schema_compat_check.py test`, see `13-compat-test.txt`):

| Candidate change | Result under BACKWARD |
|---|---|
| Add `payment_method` **with** a default | ACCEPTED |
| Add `loyalty_tier` **without** a default | REJECTED |
| Remove `user_id` | ACCEPTED |

**Bonus: what if the field had no default, or a field were removed?** Adding a field **without** a default is **rejected** under BACKWARD: a consumer on the new schema would need a value for the field when reading old records that do not contain it, and there is nothing to fill in. Removing a field is **accepted** under BACKWARD, because a new-schema reader simply ignores that data in old records. But the removal can still break old consumers that are still on the previous schema and expect the field in new records (unless that field had a default), which is exactly why BACKWARD tells you to upgrade consumers first, and why FORWARD or FULL compatibility exist for the opposite upgrade order.

**ksqlDB side effect.** The ksqlDB stream over `session_start` declares only the original columns, so it keeps working unchanged when v2 events arrive.

---

## 7. Part D - Consumer group evidence

The consumer (`src/billing_consumer.py`) is the billing system reading the enriched sessions. Settings: `group.id=billing_consumer` (demo runs use `billing_demo1`, `billing_demo2`, ...), `enable.auto.commit=false`, `partition.assignment.strategy=cooperative-sticky`, `session.timeout.ms=45000`, `heartbeat.interval.ms=3000`, `max.poll.interval.ms=300000`. Every assignment and revocation is logged.

**Partition assignment and rebalance.** With 6 partitions, one instance (A) owned all six; when B joined, a rebalance moved about half the partitions to B; when C joined, each instance owned about two. Stopping C with Ctrl+C triggered another rebalance and A and B took over its partitions.

**Captured rebalance (excerpt from `docs/evidence/20-consumer-A.txt` to `22-consumer-C.txt`):**

```
TODO: paste 8 to 12 lines here, for example:
A ASSIGNED added [0, 1, 2, 3, 4, 5] | now owns [0, 1, 2, 3, 4, 5]
A REVOKED  lost  [3, 4, 5]
B ASSIGNED added [3, 4, 5] | now owns [3, 4, 5]
...
```

Console screenshot of the consumer group (members, partitions, lag): `docs/evidence/` (consumer-group screenshot).

**Manual commits and at-least-once.** `enable.auto.commit` is false. The consumer processes a record and only then commits offsets (every 10 records and again when partitions are revoked and on shutdown). If the process dies after processing but before the commit, the group resumes from the last committed offset and those records are delivered again. Nothing is lost, but duplicates can happen, so the billing step must be idempotent: the consumer keeps a set of billed `session_id`s, and in production this would be an upsert into a database keyed by `session_id`.

**A real finding during testing.** When a member left, a regular commit in the main loop failed with `ILLEGAL_GENERATION` ("specified group generation id is not valid") because the group had just rebalanced, and the unhandled exception stopped the consumer. The fix was to catch `KafkaException` around that commit and continue: the skipped commit is repeated on the next round, which is safe under at-least-once delivery. This shows why commits can fail during rebalances and why consumers must tolerate duplicates.

**session.timeout.ms (45 s).** If the broker's group coordinator receives no heartbeat from a member for this long, it declares the member dead and triggers a rebalance. Larger values tolerate network blips; smaller values detect crashes faster.

**heartbeat.interval.ms (3 s).** How often the consumer's background thread sends heartbeats. It must be well below `session.timeout.ms` (a common rule is one third or less) so a few missed heartbeats do not cause a false failure.

**max.poll.interval.ms (5 min).** The maximum allowed time between two calls to `poll()`. Heartbeats come from a background thread, so a consumer can look alive while its processing is stuck. If `poll()` is not called within this interval, the consumer is considered failed and removed from the group. In short: `session.timeout.ms` and heartbeats detect a dead process, while `max.poll.interval.ms` detects stuck or too-slow processing.

**CooperativeSticky assignor.** With the older eager protocols (range, round-robin), every rebalance revokes all partitions from every member and then reassigns them, so the entire group pauses. CooperativeSticky is incremental: only the partitions that actually need to move are revoked, and the others keep being processed during the rebalance. It is also sticky: it tries to keep each partition with its previous owner, which minimises movement and any rebuilding of local state. The logs in `docs/evidence` show members keeping some partitions while others move.

---

## 8. Part E - ksqlDB objects

All statements are in `ksql/voltroute_pipeline.sql`, in execution order. Processing flow:

```
session_start -> session_start_stream ─┐
                                       ├─ windowed JOIN ─> completed_sessions ─ PARTITION BY station_id ─> completed_by_station ─┐
session_stop  -> session_stop_stream  ─┘                                                                                           ├─ JOIN ─> enriched_sessions ─> city_metrics_hourly (tumbling)
charging_stations -> stations_table (TABLE) ───────────────────────────────────────────────────────────────────────────────────────┘                          └> station_*_hopping (hopping)
```

**E.1 Declarations.** The key is declared as `session_id VARCHAR KEY` (and `station_id VARCHAR PRIMARY KEY` for the table) because the key format is plain KAFKA strings, so ksqlDB cannot discover the key from the registry. The other columns match the Avro fields exactly. Avro `timestamp-millis` maps to the ksqlDB `TIMESTAMP` type. The streams use `TIMESTAMP = 'start_time'` / `'stop_time'` so ksqlDB uses the event time inside the record instead of the time Kafka received it. A STREAM keeps every row; the TABLE keeps the latest row per `station_id`, which is why 16 stations never become 32 after re-running the producer.

**E.2 Windowed stream-stream join.** Every start is matched with the stop that has the same `session_id` and arrives within 4 hours (observed durations are 10 to 90 minutes, so 4 hours is a safe margin).

```sql
FROM session_start_stream st
  INNER JOIN session_stop_stream sp
  WITHIN 4 HOURS GRACE PERIOD 1 HOUR
  ON st.session_id = sp.session_id
```

A windowed join is required because start and stop are two never-ending streams: to find a match ksqlDB must remember records from each side, and it cannot remember everything forever. The window bounds how long it keeps them. `duration_minutes` is computed from the two event times in milliseconds divided by 60000, and `energy_kwh` and `station_id` are carried forward. **Starts that never get a stop** produce no row in the INNER join. ksqlDB keeps them in its join state until the window plus grace period has passed, then discards them. That is acceptable here, because `completed_sessions` is meant to contain only finished sessions. The diagnostic LEFT JOIN query shows the unmatched ones (about 9% of starts in this run), which in a real business would be abandoned or faulted sessions or lost events worth alerting on.

**E.3 Re-key and enrichment.** The completed stream is keyed by `session_id`, but the stations table is keyed by `station_id`. A stream-table join matches the stream's key against the table's key, so the stream is first re-keyed with `PARTITION BY station_id` (this writes a new topic whose records are redistributed by the new key). Then each completed session is joined to the table row for its station to add `city`, `operator` and `tariff_per_kwh`, and `session_cost = ROUND(energy_kwh * tariff_per_kwh, 2)`. A stream-table join is evaluated only when a stream record arrives; later changes to a station do not re-emit old sessions.

**Co-partitioning.** For a join, ksqlDB can only look up a key on the partition where it expects to find it, so both inputs must have (1) the same key (`station_id` on both sides), (2) the same number of partitions (6 on `charging_stations` and on `completed_by_station`) and (3) the same partitioning algorithm. I satisfied this by creating `charging_stations` with 6 partitions, creating the re-keyed stream with `PARTITIONS = 6`, and configuring my Python producers with `partitioner = murmur2_random`, which matches the hashing used by ksqlDB and Java clients (librdkafka's default is CRC32, which would place the same `station_id` on a different partition and make the join silently match nothing).

**Why stations are produced with an old record timestamp.** A stream-table join in Kafka Streams and ksqlDB processes records from the stream and the table roughly in timestamp order. The session events carry timestamps from the past 10 hours, but the station records would carry the time the producer was run (newer). ksqlDB would then process the sessions before it has loaded any station, and every join would find no match. Producing the stations with a timestamp 2 days in the past guarantees the table is loaded first. If the enrichment ever returns zero rows, this is the first thing to check; the fix is to delete and recreate `charging_stations` (6 partitions, compact) and re-run the stations producer.

**E.4 Windowed aggregations.**

- `city_metrics_hourly`: enriched sessions grouped by city in a **tumbling 1-hour** window (`WINDOW TUMBLING (SIZE 1 HOUR)`): total energy, number of completed sessions and total cost.
- `station_completed_hopping` and `station_started_hopping`: per station in a **hopping 2-hour** window advancing every 30 minutes (`WINDOW HOPPING (SIZE 2 HOURS, ADVANCE BY 30 MINUTES)`). Active sessions per window can be read as `sessions_started` minus `completed_sessions` for the same station and window (approximate: the roughly 9% of sessions that never receive a stop remain counted as active).

**Tumbling vs hopping.** A tumbling window has a fixed size and no overlap, so every event belongs to exactly one window (hourly totals that add up). A hopping window has a fixed size but advances by a smaller step, so windows overlap and one event belongs to several windows (size 2 h, advance 30 min: each event is counted in 4 windows). Hopping windows give smooth, rolling views such as the last 2 hours updated every 30 minutes, at the cost of more state and overlapping counts that must not be summed.

**Sample outputs** (screenshots in `docs/evidence/`):

| Object | Screenshot |
|---|---|
| E.1 stream and table declarations | ![E.1 create](docs/evidence/e1_create_statements.png) |
| 16 rows in `stations_table` | ![stations table](docs/evidence/e1_stations_table.png) |
| `completed_sessions` rows with `duration_minutes` | ![completed rows](docs/evidence/e2_completed_rows.png) |
| Completed session count | ![completed count](docs/evidence/e2_completed_count.png) |
| Enriched sessions (city, operator, tariff, cost) | ![enriched rows](docs/evidence/e3_enriched_rows.png) |
| Hourly metrics per city (tumbling) | ![city hourly](docs/evidence/e4_city_hourly.png) |
| Per-station completed (hopping) | ![station completed](docs/evidence/e4_station_completed.png) |
| Per-station started (hopping) | ![station started](docs/evidence/e4_station_started.png) |
| ksqlDB Flow tab | ![flow](docs/evidence/ksql_flow.png) |

```
TODO: paste 3 to 5 rows of enriched_sessions output and 3 to 5 rows of city_metrics_hourly here
```

---

## 9. Part F - Kafka Streams (bonus)

**What it does.** `kstreams/src/main/java/com/voltroute/CityEnergyApp.java` reads `enriched_sessions`, re-keys each record by city, sums `ENERGY_KWH` over **1-hour tumbling windows** (kept in a state store backed by a changelog topic) and writes each updated total to `city_energy_streams` with keys like `Delhi@2026-10-17T09:00:00Z`. It reads the upper-case field names (`CITY`, `ENERGY_KWH`) because ksqlDB wrote that topic.

**How to run.** See section 4, step 7. Create `city_energy_streams` (6 partitions) first. The app also needs `replication.factor=3` for its internal topics on Confluent Cloud. For a quick demo it is configured with `statestore.cache.max.bytes=0` and a 5-second commit interval so results are written immediately instead of being buffered for about 30 seconds.

**Evidence.** The output messages in `city_energy_streams`, the internal topics Kafka Streams created (`...-store-changelog` and `...-store-repartition`; the repartition topic showed 401 messages produced and 802 consumed in the console), and the run log `docs/evidence/50-kstreams-run.txt`.

**Kafka Streams vs ksqlDB.** The hourly per-city sum took about 10 lines of SQL in ksqlDB and no build or deployment step: serialization, state, repartitioning and the output topic are handled by the managed service. The same logic in Kafka Streams took a Maven project, explicit serdes, Java code to extract fields from generic Avro records, explicit window and grace configuration, and me running and operating the application myself. In exchange Kafka Streams gives full programmatic control (custom logic, unit tests with `TopologyTestDriver`, deployment anywhere, and no per-hour ksqlDB cost), while ksqlDB is faster to write and easier for analysts to read. Both ended up creating the same kind of internal machinery (a repartition topic and a state store backed by a changelog topic).

---

## 10. Assumptions, limitations and shortcuts

- Data is a **time-compressed replay** of a simulated 10-hour day, not real-time generation. Events are sent in event-time order with a short real delay.
- Stations were produced with a record timestamp 2 days in the past so the table loads before the stream (explained in section 8, E.3).
- Active sessions are approximated as started minus completed per window; sessions that never receive a stop stay counted as active.
- Idempotency in the consumer is an in-memory set; a real system would upsert in a database keyed by `session_id`.
- Global-access API keys and a Basic cluster were used for convenience.
- The ksqlDB cluster was created at the smallest size offered by the console (4 CSU) and deleted after capturing evidence; the output topics remain.
- Part D can read either `enriched_sessions` (the real billing input) or `session_start`; on the raw topic the city and cost fields print as `None`.
- The Confluent CLI was not used; topics were created in the console.
- The `%4|...GETPID` and `%6|...GETSUBSCRIPTIONS` lines in the producer output are harmless librdkafka log messages.

---

## Evidence index (`docs/evidence/`)

| File | What it shows |
|---|---|
| `02-stations-producer-output.txt` | First stations producer run (16 stations, 5 cities) |
| `03-session-producer-output.txt` | Session producer run (763 events, 37 starts without a stop) |
| `07-stations-rerun-output.txt` | Stations producer re-run (upsert demonstration) |
| `09-v1-consumer.txt`, `10-v2-producer-output.txt`, `11-v2-consumer.txt` | Schema evolution: v1 consumer, v2 events, v2 consumer |
| `12-schema-versions-after.txt`, `13-compat-test.txt` | Registered versions and compatibility test results |
| `20-consumer-A.txt`, `21-consumer-B.txt`, `22-consumer-C.txt` | Consumer group assignment and rebalance logs |
| `50-kstreams-run.txt` | Kafka Streams application log |
| `e1_*.png`, `e2_*.png`, `e3_*.png`, `e4_*.png`, `ksql_flow.png` | ksqlDB statement results and Flow tab |
| `kstreams_*.png` | Kafka Streams topics and output messages |
| Topic configuration, Schema Registry subjects and consumer-group screenshots | Parts A to D |

*(File names for screenshots may differ slightly in your folder; adjust the image links above to match.)*
