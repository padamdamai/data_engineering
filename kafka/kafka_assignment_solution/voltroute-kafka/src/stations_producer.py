from confluent_kafka import SerializingProducer
from confluent_kafka.serialization import StringSerializer
from confluent_kafka.schema_registry.avro import AvroSerializer
import time
from common import kafka_conf, sr_client, read_schema, build_stations, delivery_report

TOPIC = 'charging_stations'


def main():
    conf = kafka_conf()
    conf.update({
        'key.serializer': StringSerializer('utf_8'),
        'value.serializer': AvroSerializer(sr_client(), read_schema('schemas/charging_stations.avsc')),
        'partitioner': 'murmur2_random',   # same hashing as Java/ksqlDB (needed for co-partitioning)
        'acks': 'all',
        'enable.idempotence': True,
    })
    producer = SerializingProducer(conf)
    stations = build_stations()
    old_ts = int(time.time() * 1000) - 48 * 3600 * 1000   # record time 2 days ago, see Part E.3
    for s in stations:
        producer.produce(topic=TOPIC, key=s['station_id'], value=s, timestamp=old_ts, on_delivery=delivery_report)
        producer.poll(0)
    producer.flush()
    cities = sorted({s['city'] for s in stations})
    print('Produced', len(stations), 'stations across', len(cities), 'cities:', ', '.join(cities))


if __name__ == '__main__':
    main()