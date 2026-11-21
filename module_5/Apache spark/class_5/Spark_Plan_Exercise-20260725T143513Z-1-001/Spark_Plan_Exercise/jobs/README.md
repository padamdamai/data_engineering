## Spark Submit To Run Unoptimized Spark Job

```bash
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --conf spark.dynamicAllocation.enabled=false \
  --driver-memory 5g \
  --driver-cores 1 \
  --executor-memory 4g \
  --executor-cores 2 \
  --num-executors 3 \
  --conf spark.sql.shuffle.partitions=400 \
  fhvhv_zone_analytics_unoptimized.py \
  --trip-input   s3://ai-de-aws-learning-test/spark-learning/rides/tripdata/*.parquet \
  --zone-input   s3://ai-de-aws-learning-test/spark-learning/rides/tripzone/taxi_zone_lookup.csv \
  --output-base  s3://ai-de-aws-learning-test/spark-learning/rides/unoptimized
```