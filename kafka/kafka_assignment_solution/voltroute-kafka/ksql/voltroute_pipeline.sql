-- ============ E.1  Declare streams and the reference table ============
SET 'auto.offset.reset' = 'earliest';

CREATE STREAM session_start_stream (
  session_id VARCHAR KEY,
  station_id VARCHAR,
  connector_id INT,
  vehicle_id VARCHAR,
  user_id VARCHAR,
  start_time TIMESTAMP,
  start_soc_pct INT
) WITH (
  KAFKA_TOPIC = 'session_start',
  VALUE_FORMAT = 'AVRO',
  KEY_FORMAT = 'KAFKA',
  TIMESTAMP = 'start_time'
);

CREATE STREAM session_stop_stream (
  session_id VARCHAR KEY,
  station_id VARCHAR,
  stop_time TIMESTAMP,
  end_soc_pct INT,
  energy_kwh DOUBLE,
  stop_reason VARCHAR
) WITH (
  KAFKA_TOPIC = 'session_stop',
  VALUE_FORMAT = 'AVRO',
  KEY_FORMAT = 'KAFKA',
  TIMESTAMP = 'stop_time'
);

CREATE TABLE stations_table (
  station_id VARCHAR PRIMARY KEY,
  station_name VARCHAR,
  city VARCHAR,
  operator VARCHAR,
  latitude DOUBLE,
  longitude DOUBLE,
  max_power_kw DOUBLE,
  num_connectors INT,
  tariff_per_kwh DOUBLE,
  status VARCHAR
) WITH (
  KAFKA_TOPIC = 'charging_stations',
  VALUE_FORMAT = 'AVRO',
  KEY_FORMAT = 'KAFKA'
);

-- Checks (expect 16 stations, one row each):
SELECT * FROM session_start_stream EMIT CHANGES LIMIT 5;
SELECT station_id, city, tariff_per_kwh, status FROM stations_table EMIT CHANGES LIMIT 16;

-- ============ E.2  Windowed stream-stream join: start + stop ============
CREATE STREAM completed_sessions
  WITH (KAFKA_TOPIC = 'completed_sessions', PARTITIONS = 6, VALUE_FORMAT = 'AVRO') AS
SELECT
  st.session_id AS session_id,
  st.station_id AS station_id,
  st.connector_id AS connector_id,
  st.vehicle_id AS vehicle_id,
  st.user_id AS user_id,
  st.start_time AS start_time,
  sp.stop_time AS stop_time,
  st.start_soc_pct AS start_soc_pct,
  sp.end_soc_pct AS end_soc_pct,
  sp.energy_kwh AS energy_kwh,
  sp.stop_reason AS stop_reason,
  (UNIX_TIMESTAMP(sp.stop_time) - UNIX_TIMESTAMP(st.start_time)) / 60000 AS duration_minutes
FROM session_start_stream st
  INNER JOIN session_stop_stream sp
  WITHIN 4 HOURS GRACE PERIOD 1 HOUR
  ON st.session_id = sp.session_id
EMIT CHANGES;

-- Checks:
SELECT session_id, station_id, duration_minutes, energy_kwh, stop_reason
FROM completed_sessions EMIT CHANGES LIMIT 10;
SELECT 'ALL' AS k, COUNT(*) AS completed FROM completed_sessions GROUP BY 'ALL' EMIT CHANGES;

-- Optional diagnostic: starts that never got a stop (shows older ones once newer events push stream time forward)
SELECT st.session_id, st.station_id
FROM session_start_stream st
  LEFT JOIN session_stop_stream sp
  WITHIN 4 HOURS GRACE PERIOD 1 HOUR
  ON st.session_id = sp.session_id
WHERE sp.stop_time IS NULL
EMIT CHANGES LIMIT 10;

-- ============ E.3  Re-key by station_id, then stream-table enrichment ============
CREATE STREAM completed_by_station
  WITH (KAFKA_TOPIC = 'completed_by_station', PARTITIONS = 6, VALUE_FORMAT = 'AVRO') AS
SELECT
  station_id,
  session_id,
  connector_id,
  vehicle_id,
  user_id,
  start_time,
  stop_time,
  start_soc_pct,
  end_soc_pct,
  energy_kwh,
  stop_reason,
  duration_minutes
FROM completed_sessions
PARTITION BY station_id
EMIT CHANGES;

CREATE STREAM enriched_sessions
  WITH (KAFKA_TOPIC = 'enriched_sessions', PARTITIONS = 6, VALUE_FORMAT = 'AVRO') AS
SELECT
  c.station_id AS station_id,
  c.session_id AS session_id,
  s.station_name AS station_name,
  s.city AS city,
  s.operator AS operator,
  s.tariff_per_kwh AS tariff_per_kwh,
  c.vehicle_id AS vehicle_id,
  c.user_id AS user_id,
  c.start_time AS start_time,
  c.stop_time AS stop_time,
  c.duration_minutes AS duration_minutes,
  c.energy_kwh AS energy_kwh,
  c.stop_reason AS stop_reason,
  ROUND(c.energy_kwh * s.tariff_per_kwh, 2) AS session_cost
FROM completed_by_station c
  INNER JOIN stations_table s ON c.station_id = s.station_id
EMIT CHANGES;

-- Check (city, operator, tariff and session_cost must be filled in):
SELECT session_id, station_id, city, operator, tariff_per_kwh, energy_kwh, session_cost
FROM enriched_sessions EMIT CHANGES LIMIT 10;

-- ============ E.4  Windowed aggregations ============
-- Tumbling (1 hour) per city
CREATE TABLE city_metrics_hourly
  WITH (KAFKA_TOPIC = 'city_metrics_hourly', VALUE_FORMAT = 'AVRO') AS
SELECT
  city,
  WINDOWSTART AS window_start,
  WINDOWEND AS window_end,
  SUM(energy_kwh) AS total_energy_kwh,
  COUNT(*) AS completed_sessions,
  ROUND(SUM(session_cost), 2) AS total_cost
FROM enriched_sessions
WINDOW TUMBLING (SIZE 1 HOUR)
GROUP BY city
EMIT CHANGES;

-- Hopping (2-hour windows advancing every 30 minutes) per station
CREATE TABLE station_completed_hopping
  WITH (KAFKA_TOPIC = 'station_completed_hopping', VALUE_FORMAT = 'AVRO') AS
SELECT
  station_id,
  WINDOWSTART AS window_start,
  WINDOWEND AS window_end,
  LATEST_BY_OFFSET(city) AS city,
  COUNT(*) AS completed_sessions,
  SUM(energy_kwh) AS energy_kwh
FROM enriched_sessions
WINDOW HOPPING (SIZE 2 HOURS, ADVANCE BY 30 MINUTES)
GROUP BY station_id
EMIT CHANGES;

CREATE TABLE station_started_hopping
  WITH (KAFKA_TOPIC = 'station_started_hopping', VALUE_FORMAT = 'AVRO') AS
SELECT
  station_id,
  WINDOWSTART AS window_start,
  WINDOWEND AS window_end,
  COUNT(*) AS sessions_started
FROM session_start_stream
WINDOW HOPPING (SIZE 2 HOURS, ADVANCE BY 30 MINUTES)
GROUP BY station_id
EMIT CHANGES;

-- Checks / sample outputs for the README:
SELECT city,
       TIMESTAMPTOSTRING(window_start, 'yyyy-MM-dd HH:mm', 'Asia/Kolkata') AS hour_start,
       total_energy_kwh, completed_sessions, total_cost
FROM city_metrics_hourly EMIT CHANGES LIMIT 20;

SELECT station_id,
       TIMESTAMPTOSTRING(window_start, 'yyyy-MM-dd HH:mm', 'Asia/Kolkata') AS window_from,
       completed_sessions, energy_kwh
FROM station_completed_hopping EMIT CHANGES LIMIT 20;

SELECT station_id,
       TIMESTAMPTOSTRING(window_start, 'yyyy-MM-dd HH:mm', 'Asia/Kolkata') AS window_from,
       sessions_started
FROM station_started_hopping EMIT CHANGES LIMIT 20;