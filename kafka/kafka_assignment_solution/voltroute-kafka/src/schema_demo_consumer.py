import argparse
from confluent_kafka import DeserializingConsumer
from confluent_kafka.serialization import StringDeserializer
from confluent_kafka.schema_registry.avro import AvroDeserializer
from common import kafka_conf, sr_client, read_schema

ap = argparse.ArgumentParser()
ap.add_argument('--reader', choices=['v1', 'v2'], required=True)
ap.add_argument('--group', default=None, help='use a new group id to re-read from the beginning')
args = ap.parse_args()

schema_str = read_schema('schemas/session_start_' + args.reader + '.avsc')
conf = kafka_conf()
conf.update({
    'group.id': args.group or ('schema-demo-' + args.reader),
    'auto.offset.reset': 'earliest',
    'key.deserializer': StringDeserializer('utf_8'),
    'value.deserializer': AvroDeserializer(sr_client(), schema_str),
})

consumer = DeserializingConsumer(conf)
consumer.subscribe(['session_start'])
print('Reader schema:', args.reader, '- waiting for records (Ctrl+C to stop)')
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print('ERROR:', msg.error())
            continue
        v = msg.value()
        print('[' + args.reader + ']', msg.key(), v['station_id'], 'payment_method=' + str(v.get('payment_method', 'n/a')))
except KeyboardInterrupt:
    pass
finally:
    consumer.close()