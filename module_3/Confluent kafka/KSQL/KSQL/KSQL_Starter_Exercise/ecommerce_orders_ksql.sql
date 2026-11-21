-- ============================================================================
-- REAL-TIME E-COMMERCE ORDER ANALYTICS WITH ksqlDB
-- ============================================================================
-- Source Kafka topic: ecommerce_order_events_raw
-- Source value format: JSON
-- Mock input file: mock_order_events.json
--
-- Run one section at a time in the ksqlDB editor. Persistent CREATE ... AS
-- SELECT statements continue running in the background after they are created.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. READ EXISTING EVENTS WHEN THE QUERIES ARE CREATED
-- ----------------------------------------------------------------------------
-- "earliest" is useful for this exercise because the mock records may already
-- exist in Kafka before the source stream and persistent queries are created.
-- For many production deployments, "latest" is preferred for new applications.
SET 'auto.offset.reset' = 'earliest';


-- ----------------------------------------------------------------------------
-- 2. REGISTER THE RAW KAFKA TOPIC AS A ksqlDB SOURCE STREAM
-- ----------------------------------------------------------------------------
-- CREATE STREAM does not copy the data. It tells ksqlDB how to interpret each
-- JSON value already stored in the ecommerce_order_events_raw Kafka topic.
--
-- KEY_FORMAT='KAFKA' is appropriate because the mock publisher sends keyless
-- events. VALUE_FORMAT='JSON' means Schema Registry is not required here.
--
-- TIMESTAMP='event_ts' makes ROWTIME use the business-event timestamp rather
-- than the time at which Kafka received the record. event_ts must contain Unix
-- epoch milliseconds, which is how the mock events are defined.
CREATE STREAM orders_raw_stream
(
    event_id VARCHAR,
    event_ts BIGINT,
    event_type VARCHAR,
    order_id VARCHAR,
    customer_id VARCHAR,
    product_id VARCHAR,
    product_name VARCHAR,
    category VARCHAR,
    quantity INTEGER,
    unit_price DOUBLE,
    order_total DOUBLE,
    payment_method VARCHAR,
    order_status VARCHAR,
    sales_channel VARCHAR,
    city VARCHAR,
    country VARCHAR
)
WITH
(
    KAFKA_TOPIC = 'ecommerce_order_events_raw',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'JSON',
    TIMESTAMP = 'event_ts'
);


-- Show the columns, data types, backing topic, and active queries associated
-- with the source stream. EXTENDED also displays topic and consumer details.
DESCRIBE orders_raw_stream EXTENDED;


-- ----------------------------------------------------------------------------
-- 3. TRANSIENT PUSH QUERY: WATCH EVENTS ARRIVE IN REAL TIME
-- ----------------------------------------------------------------------------
-- A transient query returns results to the current client only. It does not
-- create a Kafka topic and stops when the query is cancelled.
--

SELECT
    event_ts,
    order_id,
    customer_id,
    product_name,
    quantity,
    order_total,
    order_status,
    city
FROM orders_raw_stream
EMIT CHANGES;


-- ----------------------------------------------------------------------------
-- 4. PERSISTENT STREAM: CLEAN AND VALID ORDERS
-- ----------------------------------------------------------------------------
-- This CREATE STREAM AS SELECT statement starts a persistent background query.
-- Its output is continuously written to the explicit Kafka topic below.
--
-- Cancelled, incomplete, zero-quantity, and non-positive-value records are
-- excluded so downstream analytics operate on valid commercial activity.
CREATE STREAM valid_orders_stream
WITH
(
    KAFKA_TOPIC = 'ecommerce_valid_orders',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
)
AS
SELECT
    event_id,
    event_ts,
    event_type,
    order_id,
    customer_id,
    product_id,
    product_name,
    category,
    quantity,
    unit_price,
    order_total,
    payment_method,
    order_status,
    sales_channel,
    city,
    country
FROM orders_raw_stream
WHERE order_id IS NOT NULL
  AND customer_id IS NOT NULL
  AND product_id IS NOT NULL
  AND quantity > 0
  AND unit_price > 0
  AND order_total > 0
  AND order_status <> 'CANCELLED'
EMIT CHANGES;


-- Inspect the cleaned stream. This query remains active until it is cancelled.
SELECT *
FROM valid_orders_stream
EMIT CHANGES;


-- ----------------------------------------------------------------------------
-- 5. PERSISTENT STREAM: HIGH-VALUE ORDERS KEYED BY ORDER ID
-- ----------------------------------------------------------------------------
-- PARTITION BY changes the Kafka key to order_id. This is useful because all
-- future events for the same order will then reach the same Kafka partition.
--
-- Only orders worth at least INR 5,000 are written to the user-defined topic.
CREATE STREAM high_value_orders_stream
WITH
(
    KAFKA_TOPIC = 'ecommerce_high_value_orders',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
)
AS
SELECT
    event_id,
    event_ts,
    order_id,
    customer_id,
    product_name,
    category,
    quantity,
    order_total,
    payment_method,
    order_status,
    city
FROM valid_orders_stream
WHERE order_total >= 5000.0
PARTITION BY order_id
EMIT CHANGES;


-- ----------------------------------------------------------------------------
-- 6. MATERIALIZED TABLE: RUNNING SALES SUMMARY BY CATEGORY
-- ----------------------------------------------------------------------------
-- CREATE TABLE AS SELECT builds a continuously updated materialized view.
-- Every valid order updates its category's counters and revenue totals.
--
-- GROUP BY makes category the table key. The result is also written as a
-- changelog to ecommerce_category_sales_summary for recovery and downstream use.
CREATE TABLE category_sales_summary
WITH
(
    KAFKA_TOPIC = 'ecommerce_category_sales_summary',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
)
AS
SELECT
    category,
    COUNT(*) AS total_orders,
    SUM(quantity) AS total_units,
    SUM(order_total) AS gross_revenue
FROM valid_orders_stream
GROUP BY category
EMIT CHANGES;


-- Pull the current materialized result. Unlike EMIT CHANGES, this returns the
-- current snapshot and then finishes. Pull-query support depends on deployment.
SELECT * FROM category_sales_summary;


-- Watch every future category-summary update as a continuous push query.
SELECT *
FROM category_sales_summary
EMIT CHANGES;


-- ----------------------------------------------------------------------------
-- 7. WINDOWED TABLE: CITY ORDER ACTIVITY EVERY 15 MINUTES
-- ----------------------------------------------------------------------------
-- A tumbling window creates fixed, non-overlapping 15-minute buckets based on
-- the event_ts field selected as ROWTIME in the source stream.
--
-- GRACE PERIOD allows an event arriving up to two minutes late to update its
-- correct historical window instead of being discarded immediately.
CREATE TABLE city_orders_15_minute
WITH
(
    KAFKA_TOPIC = 'ecommerce_city_orders_15_minute',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'JSON',
    PARTITIONS = 3
)
AS
SELECT
    city,
    COUNT(*) AS order_count,
    SUM(order_total) AS city_revenue
FROM valid_orders_stream
WINDOW TUMBLING
(
    SIZE 15 MINUTES,
    GRACE PERIOD 2 MINUTES
)
GROUP BY city
EMIT CHANGES;


-- WINDOWSTART and WINDOWEND expose each materialized window's boundaries as
-- Unix epoch milliseconds. This query streams window updates continuously.
SELECT
  TIMESTAMPTOSTRING(WINDOWSTART, 'yyyy-MM-dd HH:mm:ss', 'Asia/Kolkata') AS window_start_time,
  TIMESTAMPTOSTRING(WINDOWEND,   'yyyy-MM-dd HH:mm:ss', 'Asia/Kolkata') AS window_end_time,
    city,
    order_count,
    city_revenue
FROM city_orders_15_minute
EMIT CHANGES;


-- ----------------------------------------------------------------------------
-- 8. USEFUL INSPECTION COMMANDS
-- ----------------------------------------------------------------------------
-- List every stream and table currently registered in this ksqlDB application.
SHOW STREAMS;
SHOW TABLES;

-- List persistent queries and their generated query IDs.
SHOW QUERIES;

-- List Kafka topics visible to ksqlDB.
SHOW TOPICS;

-- Read five raw Kafka records without applying the stream schema.
PRINT 'ecommerce_order_events_raw' FROM BEGINNING LIMIT 5;


-- ----------------------------------------------------------------------------
-- 9. OPTIONAL CLEANUP -- RUN MANUALLY, NOT WITH THE MAIN EXERCISE
-- ----------------------------------------------------------------------------
-- Persistent queries must be terminated before their streams/tables are dropped.
-- First run SHOW QUERIES, then terminate each generated query using its real ID:
--
-- TERMINATE <query_id_for_city_orders_15_minute>;
-- TERMINATE <query_id_for_category_sales_summary>;
-- TERMINATE <query_id_for_high_value_orders_stream>;
-- TERMINATE <query_id_for_valid_orders_stream>;
--
-- After terminating the queries, remove the derived objects and their topics:
--
-- DROP TABLE IF EXISTS city_orders_15_minute DELETE TOPIC;
-- DROP TABLE IF EXISTS category_sales_summary DELETE TOPIC;
-- DROP STREAM IF EXISTS high_value_orders_stream DELETE TOPIC;
-- DROP STREAM IF EXISTS valid_orders_stream DELETE TOPIC;
--
-- Drop only the ksqlDB metadata for the source stream. The original raw Kafka
-- topic is intentionally preserved because it contains the source events:
--
-- DROP STREAM IF EXISTS orders_raw_stream;
