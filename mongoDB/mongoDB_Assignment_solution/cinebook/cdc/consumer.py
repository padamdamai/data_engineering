"""Read booking change events from Kafka (Confluent Cloud) and print them.

Usage (run from the project root, venv active):
    python3 cdc/consumer.py
Press Ctrl+C to stop.
"""
import json
import os
from collections import defaultdict

from confluent_kafka import Consumer
from dotenv import load_dotenv

load_dotenv()

TOPIC = "cdc.cinebook.bookings"


def as_obj(x):
    """The connector may deliver nested parts as JSON *strings*; turn them into objects."""
    if isinstance(x, str):
        try:
            return json.loads(x)
        except ValueError:
            return x
    return x


def parse_event(raw):
    """Return a small dict describing one change event, or None if it is not an event."""
    event = as_obj(json.loads(raw))
    if not isinstance(event, dict):
        return None
    doc = as_obj(event.get("fullDocument"))
    token = as_obj(event.get("_id"))
    if isinstance(token, dict):
        token = token.get("_data", "")
    return {
        "op": event.get("operationType"),            # insert / update / replace / delete
        "doc": doc if isinstance(doc, dict) else None,   # the booking itself (fullDocument)
        "key": as_obj(event.get("documentKey")),
        "token": str(token or ""),                   # resume token of this event
    }


def main():
    consumer = Consumer({
        "bootstrap.servers": os.environ["KAFKA_BOOTSTRAP"],
        "security.protocol": "SASL_SSL",
        "sasl.mechanisms": "PLAIN",
        "sasl.username": os.environ["KAFKA_API_KEY"],
        "sasl.password": os.environ["KAFKA_API_SECRET"],
        "group.id": "cinebook-cdc-consumer",
        "auto.offset.reset": "earliest",             # read the topic from the beginning
    })
    consumer.subscribe([TOPIC])

    tickets_per_movie = defaultdict(int)
    seen_bookings = set()
    print(f"Listening on {TOPIC} ... (Ctrl+C to stop)\n")

    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                print("Kafka error:", msg.error())
                continue
            if msg.value() is None:                  # tombstone, nothing to print
                continue

            ev = parse_event(msg.value())
            if ev is None:
                print("Unrecognised message:", msg.value()[:200])
                continue

            doc = ev["doc"]
            where = f"partition {msg.partition()}, offset {msg.offset()}"
            if doc:
                print(f"[{ev['op']}] {doc.get('_id')}  user={doc.get('user_id')}  "
                      f"show={doc.get('show_id')}  seats={doc.get('seats')}  "
                      f"amount={doc.get('amount')}  status={doc.get('status')}")
            else:
                print(f"[{ev['op']}] key={ev['key']}")
            print(f"    resume token: {ev['token'][:24]}...  ({where})")

            # live aggregate: count each booking only once, even if delivered twice
            if ev["op"] == "insert" and doc:
                if doc["_id"] in seen_bookings:
                    print("    duplicate delivery ignored")
                else:
                    seen_bookings.add(doc["_id"])
                    tickets_per_movie[doc.get("movie_title")] += len(doc.get("seats", []))
                    print(f"    live tickets per movie: {dict(tickets_per_movie)}")
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        consumer.close()


if __name__ == "__main__":
    main()