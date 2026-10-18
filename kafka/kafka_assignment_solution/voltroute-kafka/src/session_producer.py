import argparse
import random
import time
from confluent_kafka import SerializingProducer
from confluent_kafka.serialization import StringSerializer
from confluent_kafka.schema_registry.avro import AvroSerializer
from common import kafka_conf, sr_client, read_schema, build_stations, delivery_report


def make_producer(schema_path):
    conf = kafka_conf()
    conf.update({
        'key.serializer': StringSerializer('utf_8'),
        'value.serializer': AvroSerializer(sr_client(), read_schema(schema_path)),
        'partitioner': 'murmur2_random',
        'acks': 'all',
        'enable.idempotence': True,
        'linger.ms': 20,
    })
    return SerializingProducer(conf)


def make_start(sid, st, start_ms, rnd, version):
    rec = {
        'session_id': sid,
        'station_id': st['station_id'],
        'connector_id': rnd.randint(1, st['num_connectors']),
        'vehicle_id': 'EV-' + str(rnd.randint(10000, 99999)),
        'user_id': 'USR-' + str(rnd.randint(1000, 9999)),
        'start_time': start_ms,
        'start_soc_pct': rnd.randint(5, 60),
    }
    if version == 2:
        rec['payment_method'] = rnd.choice(['APP_WALLET', 'CREDIT_CARD', 'RFID_CARD'])
    return rec


def make_stop(sid, st, start, stop_ms, duration_min, rnd):
    energy = st['max_power_kw'] * (duration_min / 60) * rnd.uniform(0.3, 0.7)
    return {
        'session_id': sid,
        'station_id': st['station_id'],
        'stop_time': stop_ms,
        'end_soc_pct': rnd.randint(start['start_soc_pct'] + 10, 100),
        'energy_kwh': round(min(60.0, max(5.0, energy)), 1),
        'stop_reason': rnd.choices(['COMPLETED', 'USER_STOPPED', 'FAULT'], weights=[85, 10, 5])[0],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sessions', type=int, default=400)
    ap.add_argument('--start-id', type=int, default=1, help='first session number (use a new range per run)')
    ap.add_argument('--missing-stop-rate', type=float, default=0.08)
    ap.add_argument('--schema-version', type=int, choices=[1, 2], default=1)
    ap.add_argument('--delay', type=float, default=0.02, help='real seconds between events')
    ap.add_argument('--span-hours', type=float, default=10)
    ap.add_argument('--seed', type=int, default=None)
    args = ap.parse_args()

    rnd = random.Random(args.seed)
    stations = [s for s in build_stations() if s['status'] == 'ACTIVE']
    start_prod = make_producer('schemas/session_start_v' + str(args.schema_version) + '.avsc')
    stop_prod = make_producer('schemas/session_stop.avsc')

    now_ms = int(time.time() * 1000)
    events, missing = [], 0
    for i in range(args.sessions):
        sid = 'SESS-' + format(args.start_id + i, '06d')
        st = rnd.choice(stations)
        duration_min = rnd.randint(10, 90)
        earliest = now_ms - int(args.span_hours * 3600 * 1000)
        latest = now_ms - (duration_min + 10) * 60 * 1000
        start_ms = rnd.randint(earliest, latest)
        start = make_start(sid, st, start_ms, rnd, args.schema_version)
        events.append((start_ms, 'start', sid, start))
        if rnd.random() < args.missing_stop_rate:
            missing += 1            # no stop event: used to observe unmatched starts
            continue
        stop_ms = start_ms + duration_min * 60 * 1000
        events.append((stop_ms, 'stop', sid, make_stop(sid, st, start, stop_ms, duration_min, rnd)))

    events.sort(key=lambda e: e[0])   # replay in event-time order
    print('Sending', len(events), 'events for', args.sessions, 'sessions;', missing, 'starts have NO stop')
    for n, (ts, kind, sid, rec) in enumerate(events, 1):
        if kind == 'start':
            start_prod.produce(topic='session_start', key=sid, value=rec, on_delivery=delivery_report)
            start_prod.poll(0)
        else:
            stop_prod.produce(topic='session_stop', key=sid, value=rec, on_delivery=delivery_report)
            stop_prod.poll(0)
        if n % 100 == 0:
            print('  sent', n, 'events')
        time.sleep(args.delay)
    start_prod.flush()
    stop_prod.flush()
    print('Done.')


if __name__ == '__main__':
    main()