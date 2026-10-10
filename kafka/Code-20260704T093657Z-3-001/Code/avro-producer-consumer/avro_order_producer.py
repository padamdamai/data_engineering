import logging
import random
import time
import uuid

# Producer is the standard Confluent Kafka producer.
from confluent_kafka import Producer

# SchemaRegistryClient connects to Schema Registry.
# topic_subject_name_strategy maps the topic to the "<topic>-value" subject.
from confluent_kafka.schema_registry import SchemaRegistryClient, topic_subject_name_strategy

# AvroSerializer converts the Python dictionary into Avro binary data.
from confluent_kafka.schema_registry.avro import AvroSerializer

# These classes tell each serializer whether it is handling a message key or value.
from confluent_kafka.serialization import MessageField, SerializationContext


# Configure a simple log format containing time, log level, and message.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

# Create the logger used throughout this file.
LOGGER = logging.getLogger("avro-order-producer")


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

# Kafka topic into which order events will be published.
TOPIC = "ecomm_orders_raw_new"

# TopicNameStrategy stores the key schema under "<topic-name>-key".
KEY_SCHEMA_SUBJECT = f"{TOPIC}-key"

# TopicNameStrategy stores the value schema under "<topic-name>-value".
VALUE_SCHEMA_SUBJECT = f"{TOPIC}-value"

# Number of dynamic order events created each time the producer is run.
NUMBER_OF_EVENTS = 1000

# Sample customers contain only IDs and countries, not personal information.
# The country is used as the order's shipping destination.
CUSTOMERS = [
    {"customer_id": "customer-1001", "shipping_country": "IN"},
    {"customer_id": "customer-1002", "shipping_country": "IN"},
    {"customer_id": "customer-1003", "shipping_country": "SG"},
    {"customer_id": "customer-1004", "shipping_country": "AE"},
]

# This product catalog stores prices in paise, the minor unit of INR.
# Integer prices prevent rounding errors caused by floating-point money values.
PRODUCT_CATALOG = [
    {"sku": "LAPTOP-STAND-001", "unit_price_minor": 249900},
    {"sku": "WIRELESS-MOUSE-002", "unit_price_minor": 129900},
    {"sku": "USB-C-HUB-003", "unit_price_minor": 349900},
    {"sku": "MECHANICAL-KEYBOARD-004", "unit_price_minor": 599900},
    {"sku": "NOISE-CANCELLING-HEADSET-005", "unit_price_minor": 799900},
]

# Count successful and failed broker acknowledgements for final validation.
DELIVERED_MESSAGE_COUNT = 0
FAILED_MESSAGE_COUNT = 0


def delivery_report(error, message):
    """Log whether Kafka successfully stored the produced message."""

    # Allow this callback to update the module-level delivery counters.
    global DELIVERED_MESSAGE_COUNT, FAILED_MESSAGE_COUNT

    # Kafka passes an error object when message delivery fails.
    if error is not None:
        # Count the failed acknowledgement so main() can fail the program.
        FAILED_MESSAGE_COUNT += 1
        LOGGER.error("Message delivery failed: %s", error)
        return

    # Count the successful acknowledgement received from Kafka.
    DELIVERED_MESSAGE_COUNT += 1

    # This message is printed after Kafka acknowledges the record.
    LOGGER.info(
        "Message delivered to topic=%s partition=%s offset=%s",
        message.topic(),
        message.partition(),
        message.offset(),
    )


def generate_order_event():
    """Create one internally consistent order-created business event."""

    # Select the customer who is placing this order.
    customer = random.choice(CUSTOMERS)

    # Select between one and three different products for this order.
    selected_products = random.sample(
        PRODUCT_CATALOG,
        k=random.randint(1, 3),
    )

    # Start with an empty list that will contain the purchased items.
    order_items = []

    # Convert each selected catalog product into an order line item.
    for product in selected_products:
        # Select a realistic quantity between one and three units.
        quantity = random.randint(1, 3)

        # Add the selected product, quantity, and current unit price to the order.
        order_items.append(
            {
                "sku": product["sku"],
                "quantity": quantity,
                "unit_price_minor": product["unit_price_minor"],
            }
        )

    # Calculate the order total from its item prices and quantities.
    # This guarantees that the total has a real business relationship to the items.
    total_amount_minor = sum(
        item["quantity"] * item["unit_price_minor"]
        for item in order_items
    )

    # Return an event that matches the schema registered in Schema Registry.
    return {
        # A unique event ID allows consumers to identify duplicate deliveries.
        "event_id": str(uuid.uuid4()),
        # A newly generated order always begins with ORDER_CREATED.
        "event_type": "ORDER_CREATED",
        # Version of the business event contract.
        "event_version": 1,
        # Current Unix time in milliseconds for Avro's timestamp-millis type.
        "occurred_at": int(time.time() * 1000),
        # Every generated order receives its own unique order ID.
        "order_id": f"order-{uuid.uuid4()}",
        # Store the selected customer ID in the event payload.
        "customer_id": customer["customer_id"],
        # ORDER_CREATED corresponds to the initial CREATED order state.
        "order_status": "CREATED",
        # All catalog prices in this example are expressed in INR.
        "currency": "INR",
        # The total is calculated rather than filled with an unrelated random number.
        "total_amount_minor": total_amount_minor,
        # Include all dynamically selected and priced order lines.
        "items": order_items,
        # Use the selected customer's country as the shipping destination.
        "shipping_country": customer["shipping_country"],
        # Add useful non-sensitive source and tracing information.
        "metadata": {
            "source": "checkout-service",
            "sales_channel": random.choice(["WEB", "MOBILE_APP"]),
            "trace_id": uuid.uuid4().hex,
        },
    }


def main():
    """Fetch the latest schema, generate orders, and publish them to Kafka."""

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
    # This makes the program fail early if the Avro key schema is missing.
    latest_key_schema = schema_registry_client.get_latest_version(KEY_SCHEMA_SUBJECT)

    # Fetch the latest schema registered for this topic's value subject.
    # This makes the program fail early if the Avro value schema is missing.
    latest_value_schema = schema_registry_client.get_latest_version(VALUE_SCHEMA_SUBJECT)

    # Log the exact key schema version and global schema ID found in Schema Registry.
    LOGGER.info(
        "Using key subject=%s version=%s schema_id=%s",
        KEY_SCHEMA_SUBJECT,
        latest_key_schema.version,
        latest_key_schema.schema_id,
    )

    # Log the exact value schema version and global schema ID found in Schema Registry.
    LOGGER.info(
        "Using value subject=%s version=%s schema_id=%s",
        VALUE_SCHEMA_SUBJECT,
        latest_value_schema.version,
        latest_value_schema.schema_id,
    )

    # Create the Avro key serializer.
    # schema_str=None means the key schema is obtained only from Schema Registry.
    key_avro_serializer = AvroSerializer(
        schema_registry_client=schema_registry_client,
        schema_str=None,
        conf={
            # Never create or modify the key schema from producer code.
            "auto.register.schemas": False,
            # Always use the latest ecomm_orders-key schema version.
            "use.latest.version": True,
            # MessageField.KEY will map this serializer to "<topic>-key".
            "subject.name.strategy": topic_subject_name_strategy,
        },
    )

    # Create the Avro value serializer.
    # schema_str=None means the value schema is obtained only from Schema Registry.
    value_avro_serializer = AvroSerializer(
        schema_registry_client=schema_registry_client,
        schema_str=None,
        conf={
            # Never create or modify the value schema from producer code.
            "auto.register.schemas": False,
            # Always use the latest ecomm_orders-value schema version.
            "use.latest.version": True,
            # MessageField.VALUE will map this serializer to "<topic>-value".
            "subject.name.strategy": topic_subject_name_strategy,
        },
    )

    # Configure the Kafka producer.
    producer = Producer(
        {
            # Tell the producer which Confluent Cloud Kafka cluster to use.
            "bootstrap.servers": BOOTSTRAP_SERVERS,
            # Encrypt the connection and authenticate it using SASL.
            "security.protocol": "SASL_SSL",
            # Confluent Cloud API credentials use the PLAIN SASL mechanism.
            "sasl.mechanism": "PLAIN",
            # Kafka cluster API key used as the SASL username.
            "sasl.username": KAFKA_API_KEY,
            # Kafka cluster API secret used as the SASL password.
            "sasl.password": KAFKA_API_SECRET,
            # Wait for all in-sync replicas to acknowledge the message.
            "acks": "all",
            # Avoid duplicate records if Kafka retries a temporary failure.
            "enable.idempotence": True,
        }
    )

    # Generate and publish the configured number of independent orders.
    for event_number in range(1, NUMBER_OF_EVENTS + 1):
        # Generate fresh business data for this iteration.
        order_event = generate_order_event()

        # Keep customer_id for business logging and for the event value.
        customer_id = order_event["customer_id"]

        # Use the unique order_id as the Kafka key for this generated order.
        # Future events for this same order should reuse this order_id key.
        order_id = order_event["order_id"]

        # Log important business identifiers without logging the binary payload.
        LOGGER.info(
            "Publishing event=%s/%s order_id=%s customer_id=%s total_minor=%s",
            event_number,
            NUMBER_OF_EVENTS,
            order_id,
            customer_id,
            order_event["total_amount_minor"],
        )

        # Build the key record required by the ecomm_orders-key Avro schema.
        # generate_order_event() creates a new UUID-based order_id for every order.
        order_key = {"order_id": order_id}

        # Serialize the key using the latest key schema from Schema Registry.
        serialized_key = key_avro_serializer(
            order_key,
            SerializationContext(TOPIC, MessageField.KEY),
        )

        # Serialize the value using the latest value schema from Schema Registry.
        serialized_value = value_avro_serializer(
            order_event,
            SerializationContext(TOPIC, MessageField.VALUE),
        )

        # Add the message to the producer queue.
        producer.produce(
            # Destination Kafka topic.
            topic=TOPIC,
            # The key is Confluent-framed Avro data containing the unique order_id.
            # Kafka hashes different order IDs across the topic's available partitions.
            key=serialized_key,
            # The value is now Confluent-framed Avro binary data.
            value=serialized_value,
            # Kafka calls this function after delivery succeeds or fails.
            on_delivery=delivery_report,
        )

        # flush() blocks until this message is acknowledged or the timeout expires.
        # Calling it inside the loop provides synchronous behavior for every event.
        messages_still_queued = producer.flush(timeout=10)

        # A non-zero result means this message was not delivered within the timeout.
        if messages_still_queued > 0:
            raise RuntimeError(f"{messages_still_queued} message(s) were not delivered")

        # Stop immediately if the delivery callback reported a permanent Kafka error.
        if FAILED_MESSAGE_COUNT > 0:
            raise RuntimeError("Kafka failed to deliver a message")

        # Wait briefly to simulate orders arriving over time instead of all at once.
        time.sleep(3)

    # Ensure every generated event received a successful broker acknowledgement.
    if DELIVERED_MESSAGE_COUNT != NUMBER_OF_EVENTS:
        raise RuntimeError(
            f"Expected {NUMBER_OF_EVENTS} acknowledgements but received "
            f"{DELIVERED_MESSAGE_COUNT}"
        )

    # Confirm that the producer completed its work.
    LOGGER.info("Producer finished successfully. delivered=%s", DELIVERED_MESSAGE_COUNT)


# Run main() only when this file is executed directly.
if __name__ == "__main__":
    # Log startup or runtime failures with their full stack trace.
    try:
        main()
    except Exception:
        LOGGER.exception("Producer stopped because of an error")
        raise
