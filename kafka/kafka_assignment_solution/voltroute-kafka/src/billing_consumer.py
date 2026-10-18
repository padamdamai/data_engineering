import argparse
import os
import time
from confluent_kafka import DeserializingConsumer, KafkaException
from confluent_kafka.serialization import StringDeserializer
from confluent_kafka.schema_registry.avro import AvroDeserializer
from common import kafka_conf, sr_client

ap = argparse.ArgumentParser()
ap.add_argument('--topic', default='enriched_sessions')
ap.add_argument('--group', default='billing_consumer')
ap.add_argument('--name', default=None, help='label for this instance in the logs')
ap.add_argument('--commit-every', type=int, default=10)
ap.add_argument('--process-ms', type=int, default=200, help='simulated work per record')
args = ap.parse_args()
NAME = args.name or ('instance-' + str(os.getpid()))

conf = kafka_conf()
conf.update({
    'group.id': args.group,
    'key.deserializer': StringDeserializer('utf_8'),
    'value.deserializer': AvroDeserializer(sr_client()),   # uses the writer schema from the registry
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False,                           # manual commits
    'partition.assignment.strategy': 'cooperative-sticky',
    'session.timeout.ms': 45000,
    'heartbeat.interval.ms': 3000,
    'max.poll.interval.ms': 300000,
})

owned = set()


def on_assign(consumer, partitions):
    consumer.incremental_assign(partitions)
    owned.update(p.partition for p in partitions)
    print(NAME, 'ASSIGNED added', sorted(p.partition for p in partitions), '| now owns', sorted(owned), flush=True)


def on_revoke(consumer, partitions):
    print(NAME, 'REVOKED  lost ', sorted(p.partition for p in partitions), flush=True)
    try:
        consumer.commit(asynchronous=False)       # save progress before giving partitions away
    except KafkaException:
        pass
    consumer.incremental_unassign(partitions)
    owned.difference_update(p.partition for p in partitions)
    print(NAME, 'now owns', sorted(owned), flush=True)


def field(v, name):
    # ksqlDB writes upper-case Avro field names; raw topics use lower-case
    return v.get(name, v.get(name.upper()))


consumer = DeserializingConsumer(conf)
consumer.subscribe([args.topic], on_assign=on_assign, on_revoke=on_revoke)
billed = set()      # idempotency guard (a real system would upsert into a database by session_id)
since_commit = 0
print(NAME, 'started in group', args.group, 'on topic', args.topic, flush=True)
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(NAME, 'ERROR', msg.error(), flush=True)
            continue
        v = msg.value()
        sid = field(v, 'session_id')
        if sid in billed:
            print(NAME, 'DUPLICATE skipped', sid, flush=True)
        else:
            time.sleep(args.process_ms / 1000)     # pretend to bill the customer
            billed.add(sid)
            print(NAME, 'p=' + str(msg.partition()), 'o=' + str(msg.offset()), sid,
                  'city=' + str(field(v, 'city')), 'cost=' + str(field(v, 'session_cost')), flush=True)
        since_commit += 1
        if since_commit >= args.commit_every:
            try:
                consumer.commit(asynchronous=False)
            except KafkaException as e:
                print(NAME, 'COMMIT skipped during rebalance:', e.args[0].name(), flush=True)
            since_commit = 0
except KeyboardInterrupt:
    pass
finally:
    try:
        consumer.commit(asynchronous=False)
    except KafkaException:
        pass
    consumer.close()       # leaves the group cleanly so partitions are reassigned immediately