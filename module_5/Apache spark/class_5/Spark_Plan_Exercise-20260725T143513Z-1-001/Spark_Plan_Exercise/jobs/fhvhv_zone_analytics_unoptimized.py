"""
Unoptimized Spark job for NYC FHVHV trip analytics.

Business question:
    How do FHVHV trips perform by pickup borough/platform per day and by pickup
    zone per month?
"""

import argparse
import logging
import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType, StringType, StructField, StructType


ZONE_SCHEMA = StructType(
    [
        StructField("LocationID", IntegerType(), nullable=False),
        StructField("Borough", StringType(), nullable=True),
        StructField("Zone", StringType(), nullable=True),
        StructField("service_zone", StringType(), nullable=True),
    ]
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run unoptimized FHVHV Spark analytics job."
    )
    parser.add_argument(
        "--trip-input",
        default="data/fhvhv_tripdata_2024-*.parquet",
        help="Input parquet path. Example: s3a://bucket/fhvhv_tripdata_2024-*.parquet",
    )
    parser.add_argument(
        "--zone-input",
        default="data/taxi_zone_lookup.csv",
        help="Taxi zone lookup CSV path. Example: s3a://bucket/taxi_zone_lookup.csv",
    )
    parser.add_argument(
        "--output-base",
        default="output/unoptimized_fhvhv_zone_analytics",
        help="Base output path for this job.",
    )
    return parser.parse_args()


def configure_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s - %(message)s",
        stream=sys.stdout,
    )
    return logging.getLogger("fhvhv-zone-analytics-unoptimized")


def build_spark(args):
    return (
        SparkSession.builder.appName("fhvhv-zone-analytics-unoptimized")
        .config("spark.sql.adaptive.enabled", "false")
        # automatically broadcast, so the Spark plan should show a shuffle join.
        .config("spark.sql.autoBroadcastJoinThreshold", "-1")
        # removes a storage-level optimization so the scan path
        # is more expensive
        .config("spark.sql.parquet.filterPushdown", "false")
        .getOrCreate()
    )


def read_inputs(spark, args, logger):
    logger.info("Reading trip parquet data from %s", args.trip_input)
    trips_raw = spark.read.parquet(args.trip_input)

    logger.info("Reading taxi zone lookup from %s", args.zone_input)
    zones_raw = (
        spark.read.option("header", "true")
        .schema(ZONE_SCHEMA)
        .csv(args.zone_input)
    )

    return trips_raw, zones_raw


def build_unoptimized_analytics(trips_raw, zones_raw):
    """
    Build two output DataFrames with transformations:
        1. join with pickup zone lookup
        2. groupBy for daily borough/platform metrics
        3. groupBy for monthly pickup zone metrics
    """

    # Narrow transformations, intentionally done before pruning the raw trip
    # dataset. The raw_payload_size expression touches every source column and
    # feeds a no-op filter later. That keeps unnecessary columns visible in the
    # physical plan instead of letting Catalyst prune them all away.
    raw_payload_text = F.concat_ws(
        "||",
        *[
            F.coalesce(F.col(column_name).cast("string"), F.lit(""))
            for column_name in trips_raw.columns
        ],
    )
    trips_with_derived_columns = (
        trips_raw.withColumn("raw_payload_size", F.length(raw_payload_text))
        .withColumn("trip_date", F.to_date("pickup_datetime"))
        .withColumn("trip_month", F.date_format("pickup_datetime", "yyyy-MM"))
        .withColumn("pickup_hour", F.hour("pickup_datetime"))
        .withColumn("trip_duration_minutes", F.col("trip_time") / F.lit(60.0))
        .withColumn(
            "gross_trip_value",
            F.col("base_passenger_fare")
            + F.col("tolls")
            + F.col("bcf")
            + F.col("sales_tax")
            + F.col("congestion_surcharge")
            + F.col("airport_fee")
            + F.col("tips"),
        )
        .withColumn(
            "is_shared_trip",
            F.when(F.col("shared_request_flag") == F.lit("Y"), F.lit(1)).otherwise(
                F.lit(0)
            ),
        )
        .withColumn(
            "is_airport_trip",
            F.when(F.col("airport_fee") > F.lit(0), F.lit(1)).otherwise(F.lit(0)),
        )
    )

    # Narrow transformation on the small lookup, but no broadcast hint is used.
    # Combined with spark.sql.autoBroadcastJoinThreshold=-1, this should appear
    # as a shuffle-based join in the SQL tab.
    pickup_zones = zones_raw.select(
        F.col("LocationID").alias("PULocationID"),
        F.col("Borough").alias("pickup_borough"),
        F.col("Zone").alias("pickup_zone"),
        F.col("service_zone"),
    )

    # WIDE TRANSFORMATION 1: shuffle join.
    # joining before filtering and before a tight
    # final projection makes Spark carry more data through the expensive join.
    enriched_trips = trips_with_derived_columns.join(
        pickup_zones, on="PULocationID", how="left"
    )

    # Narrow transformations applied late. The optimized version does this
    # before the join so fewer rows and columns reach the wide part of the plan.
    filtered_enriched_trips = (
        enriched_trips.filter(F.col("raw_payload_size") >= F.lit(0))
        .filter(F.col("pickup_datetime").isNotNull())
        .filter(F.col("dropoff_datetime").isNotNull())
        .filter(F.col("trip_miles") > F.lit(0))
        .filter(F.col("trip_time") > F.lit(0))
        .filter(F.col("base_passenger_fare") >= F.lit(0))
    )

    total_miles = F.sum("trip_miles")
    total_passenger_fare = F.sum("base_passenger_fare")
    fare_per_mile = F.when(
        total_miles != F.lit(0.0), total_passenger_fare / total_miles
    )

    # WIDE TRANSFORMATION 2: daily business aggregation.
    daily_borough_platform_metrics = filtered_enriched_trips.groupBy(
        "trip_date", "pickup_borough", "hvfhs_license_num"
    ).agg(
        F.count(F.lit(1)).alias("trip_count"),
        F.round(total_miles, 2).alias("total_miles"),
        F.round(F.sum("trip_duration_minutes"), 2).alias("total_trip_minutes"),
        F.round(total_passenger_fare, 2).alias("total_passenger_fare"),
        F.round(F.sum("driver_pay"), 2).alias("total_driver_pay"),
        F.round(fare_per_mile, 2).alias("avg_fare_per_mile"),
        F.round(F.avg("driver_pay"), 2).alias("avg_driver_pay_per_trip"),
        F.sum("is_shared_trip").alias("shared_trip_count"),
    )

    # WIDE TRANSFORMATION 3: monthly pickup zone aggregation.
    monthly_zone_metrics = filtered_enriched_trips.groupBy(
        "trip_month", "pickup_borough", "pickup_zone", "service_zone"
    ).agg(
        F.count(F.lit(1)).alias("trip_count"),
        F.round(F.sum("gross_trip_value"), 2).alias("total_gross_trip_value"),
        F.round(F.sum("tips"), 2).alias("total_tips"),
        F.round(F.sum("driver_pay"), 2).alias("total_driver_pay"),
        F.round(F.avg("trip_miles"), 2).alias("avg_trip_miles"),
        F.round(F.avg("trip_duration_minutes"), 2).alias("avg_trip_minutes"),
        F.sum("is_airport_trip").alias("airport_trip_count"),
        F.round(F.sum("congestion_surcharge"), 2).alias("total_congestion_surcharge"),
    )

    return daily_borough_platform_metrics, monthly_zone_metrics


def write_outputs(daily_metrics, monthly_metrics, output_base, logger):
    daily_output = f"{output_base.rstrip('/')}/daily_borough_platform_metrics"
    monthly_output = f"{output_base.rstrip('/')}/monthly_pickup_zone_metrics"

    # ACTION 1: write daily metrics.
    # because this script does not persist the shared
    # enriched DataFrame, this action computes the scan, join, and aggregation.
    logger.info("Writing daily borough/platform metrics to %s", daily_output)
    daily_metrics.write.mode("overwrite").parquet(daily_output)

    # ACTION 2: write monthly metrics.
    # the scan and join lineage will run again for this
    # second action, making recomputation visible in Jobs and Stages.
    logger.info("Writing monthly pickup zone metrics to %s", monthly_output)
    monthly_metrics.write.mode("overwrite").parquet(monthly_output)


def main():
    args = parse_args()
    logger = configure_logging()
    spark = build_spark(args)
    spark.sparkContext.setLogLevel("WARN")

    logger.info("Starting unoptimized FHVHV analytics job")
    logger.info("AQE enabled? %s", spark.conf.get("spark.sql.adaptive.enabled"))
    logger.info(
        "Shuffle partitions: %s", spark.conf.get("spark.sql.shuffle.partitions")
    )
    logger.info(
        "Auto broadcast join threshold: %s",
        spark.conf.get("spark.sql.autoBroadcastJoinThreshold"),
    )

    try:
        trips_raw, zones_raw = read_inputs(spark, args, logger)
        daily_metrics, monthly_metrics = build_unoptimized_analytics(
            trips_raw, zones_raw
        )

        write_outputs(daily_metrics, monthly_metrics, args.output_base, logger)
        logger.info("Finished unoptimized FHVHV analytics job")
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
