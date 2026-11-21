# json formats the deserialized Python dictionary before printing it.
import json

# logging prints clear informational and error messages while the program runs.
import logging

import time

# Consumer reads Kafka records; KafkaException represents Kafka client errors.
from confluent_kafka import Consumer, KafkaException

# SchemaRegistryClient retrieves schemas from Schema Registry.
# topic_subject_name_strategy maps the topic to the "<topic>-value" subject.
from confluent_kafka.schema_registry import SchemaRegistryClient, topic_subject_name_strategy

# AvroDeserializer converts Confluent Avro binary data into a Python dictionary.
from confluent_kafka.schema_registry.avro import AvroDeserializer

# These classes tell each deserializer whether it is reading a message key or value.
from confluent_kafka.serialization import MessageField, SerializationContext


# Configure a simple log format containing time, log level, and message.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

# Create the logger used throughout this file.
LOGGER = logging.getLogger("avro-order-consumer")


# Confluent Cloud Kafka bootstrap server copied from the cluster settings.
BOOTSTRAP_SERVERS = "pkc-oxqxx9.us-east-1.aws.confluent.cloud:9092"

# Kafka cluster API credentials created in Confluent Cloud.
# Replace these placeholders before running the producer.
KAFKA_API_KEY = "JTSAP7VKF6RLGSHT"
KAFKA_API_SECRET = "cflty96+6+Yd6pEX7Tj35okxHq6Io5PCxLh/HPDdpQQsPoOuwtKCwhywvMK02g3w"

# Confluent Cloud Schema Registry endpoint copied from the environment settings.
SCHEMA_REGISTRY_URL = "https://psrc-4m2v5xk.us-east-1.aws.confluent.cloud"

# Schema Registry uses a separate API key and secret from the Kafka cluster.
# Replace these placeholders with Schema Registry credentials.
SCHEMA_REGISTRY_API_KEY = "5PO52MMNBI36FBHT"
SCHEMA_REGISTRY_API_SECRET = "cfltBilwxjHck89006d6bwd++FgTZlmwOC9M2IojybLiZOPJgcWPoMcDtsU4/h6A"

# Kafka topic from which order events will be consumed.
TOPIC = "ecomm_orders_raw_new"

# TopicNameStrategy stores the key schema under "<topic-name>-key".
KEY_SCHEMA_SUBJECT = f"{TOPIC}-key"

# TopicNameStrategy stores the value schema under "<topic-name>-value".
VALUE_SCHEMA_SUBJECT = f"{TOPIC}-value"


def main():
    """Fetch the latest reader schema and continuously consume order events."""

    # Create an authenticated client that can communicate with Schema Registry.
    schema_registry_client = SchemaRegistryClient(
        {
            # HTTPS endpoint of the Confluent Cloud Schema Registry.
            "url": SCHEMA_REGISTRY_URL,
            # Send the Schema Registry API key and secret using HTTP Basic authentication.
            "basic.auth.user.info": (
                f"{SCHEMA_REGISTRY_API_KEY}:{SCHEMA_REGISTRY_API_SECRET}"
            ),
        }
    )

    # Fetch the latest schema registered for this topic's key subject.
    # This makes the consumer fail early if the Avro key schema is missing.
    latest_key_schema = schema_registry_client.get_latest_version(KEY_SCHEMA_SUBJECT)

    # Fetch the latest schema registered for this topic's value subject.
    # This makes the consumer fail early if the Avro value schema is missing.
    latest_value_schema = schema_registry_client.get_latest_version(VALUE_SCHEMA_SUBJECT)

    # Log the exact key schema version and global schema ID selected by the consumer.
    LOGGER.info(
        "Using key subject=%s version=%s schema_id=%s",
        KEY_SCHEMA_SUBJECT,
        latest_key_schema.version,
        latest_key_schema.schema_id,
    )

    # Log the exact value schema version and global schema ID selected by the consumer.
    LOGGER.info(
        "Using value subject=%s version=%s schema_id=%s",
        VALUE_SCHEMA_SUBJECT,
        latest_value_schema.version,
        latest_value_schema.schema_id,
    )

    # Create the Avro key deserializer without supplying any local schema.
    # The latest ecomm_orders-key version is used as the Avro reader schema.
    key_avro_deserializer = AvroDeserializer(
        schema_registry_client=schema_registry_client,
        schema_str=None,
        conf={
            # Read keys using the latest registered key schema version.
            "use.latest.version": True,
            # MessageField.KEY will map this deserializer to "<topic>-key".
            "subject.name.strategy": topic_subject_name_strategy,
        },
    )

    # Create the Avro value deserializer without supplying any local schema.
    # The latest ecomm_orders-value version is used as the Avro reader schema.
    value_avro_deserializer = AvroDeserializer(
        schema_registry_client=schema_registry_client,
        schema_str=None,
        conf={
            # Read values using the latest registered value schema version.
            "use.latest.version": True,
            # MessageField.VALUE will map this deserializer to "<topic>-value".
            "subject.name.strategy": topic_subject_name_strategy,
        },
    )

    # Configure the Kafka consumer.
    consumer = Consumer(
        {
            # Tell the consumer which Confluent Cloud Kafka cluster to use.
            "bootstrap.servers": BOOTSTRAP_SERVERS,
            # Encrypt the connection and authenticate it using SASL.
            "security.protocol": "SASL_SSL",
            # Confluent Cloud API credentials use the PLAIN SASL mechanism.
            "sasl.mechanism": "PLAIN",
            # Kafka cluster API key used as the SASL username.
            "sasl.username": KAFKA_API_KEY,
            # Kafka cluster API secret used as the SASL password.
            "sasl.password": KAFKA_API_SECRET,
            # Consumers with this group ID share the topic partitions.
            "group.id": "G1",
            # Start from the earliest record when this group has no committed offset.
            "auto.offset.reset": "earliest",
            # Disable timer-based commits because processing controls commits.
            "enable.auto.commit": False,
        }
    )

    # Subscribe the consumer to the order-events topic.
    consumer.subscribe([TOPIC])

    # Tell the user that the consumer is now waiting for records.
    LOGGER.info("Consumer started. Waiting for messages from topic=%s", TOPIC)

    try:
        # Continue polling until the user stops the program with Ctrl+C.
        while True:
            # Wait up to one second for the next Kafka message.
            message = consumer.poll(timeout=1.0)

            # A None result simply means no message arrived during this poll.
            if message is None:
                continue

            # Stop processing if Kafka returned an actual consumer error.
            if message.error():
                raise KafkaException(message.error())

            # Create the context needed to locate the topic's key schema.
            key_context = SerializationContext(message.topic(), MessageField.KEY)

            # Deserialize the Avro key bytes into an OrderKey dictionary.
            order_key = key_avro_deserializer(message.key(), key_context)

            # Create the context needed to locate the topic's value schema.
            value_context = SerializationContext(message.topic(), MessageField.VALUE)

            # Deserialize the Avro value bytes into an OrderEvent dictionary.
            order_event = value_avro_deserializer(message.value(), value_context)

            # Read the unique order_id from the deserialized Avro key record.
            order_id = order_key["order_id"]

            # Print the message key and deserialized value in readable JSON format.
            # default=str safely formats Avro logical values such as timestamps.
            print(
                json.dumps(
                    {"key": order_key, "value": order_event},
                    indent=2,
                    default=str,
                )
            )

            # Log where the successfully processed message came from.
            LOGGER.info(
                "Processed order_id=%s partition=%s offset=%s",
                order_id,
                message.partition(),
                message.offset(),
            )

            # Commit offset+1 for this message and wait for Kafka's response.
            # If deserialization or printing failed, execution never reaches this line.
            consumer.commit(message=message, asynchronous=False)

            # Confirm that the synchronous offset commit completed.
            LOGGER.info("Offset committed synchronously")

            time.sleep(3)

            print("======================================================")


    # Ctrl+C raises KeyboardInterrupt and is the normal way to stop this example.
    except KeyboardInterrupt:
        LOGGER.info("Consumer stopped by user")

    # Log unexpected errors before allowing them to terminate the program.
    except Exception:
        LOGGER.exception("Consumer stopped because of an error")
        raise

    # This block always runs, whether the loop succeeds, fails, or is interrupted.
    finally:
        # Leave the consumer group cleanly and release network resources.
        consumer.close()

        # Confirm that cleanup has completed.
        LOGGER.info("Consumer connection closed")


# Run main() only when this file is executed directly.
if __name__ == "__main__":
    main()
