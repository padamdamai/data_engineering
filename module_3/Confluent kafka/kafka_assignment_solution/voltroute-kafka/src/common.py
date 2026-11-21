import os
import random
from dotenv import load_dotenv
from confluent_kafka.schema_registry import SchemaRegistryClient

load_dotenv()


def kafka_conf():
    return {
        'bootstrap.servers': os.environ['BOOTSTRAP_SERVERS'],
        'security.protocol': 'SASL_SSL',
        'sasl.mechanisms': 'PLAIN',
        'sasl.username': os.environ['KAFKA_API_KEY'],
        'sasl.password': os.environ['KAFKA_API_SECRET'],
    }


def sr_client():
    return SchemaRegistryClient({
        'url': os.environ['SR_URL'],
        'basic.auth.user.info': os.environ['SR_API_KEY'] + ':' + os.environ['SR_API_SECRET'],
    })


def read_schema(path):
    with open(path) as f:
        return f.read()


def delivery_report(err, msg):
    if err is not None:
        print('DELIVERY FAILED:', err)


CITY_INFO = {  # city: (code, latitude, longitude)
    'Delhi': ('DEL', 28.6139, 77.2090),
    'Mumbai': ('MUM', 19.0760, 72.8777),
    'Bengaluru': ('BLR', 12.9716, 77.5946),
    'Hyderabad': ('HYD', 17.3850, 78.4867),
    'Pune': ('PNQ', 18.5204, 73.8567),
}
STATIONS_PER_CITY = {'Delhi': 4, 'Mumbai': 4, 'Bengaluru': 3, 'Hyderabad': 3, 'Pune': 2}
AREAS = ['Central Hub', 'Airport Plaza', 'Tech Park', 'Mall Road',
         'Railway Station', 'University Gate', 'Ring Road', 'Metro Point']


def build_stations():
    rnd = random.Random(42)  # fixed seed: identical output on every run
    stations, n = [], 0
    for city, count in STATIONS_PER_CITY.items():
        code, lat, lon = CITY_INFO[city]
        for i in range(1, count + 1):
            n += 1
            stations.append({
                'station_id': 'ST-' + code + '-' + format(i, '03d'),
                'station_name': city + ' ' + AREAS[(i - 1) % len(AREAS)],
                'city': city,
                'operator': 'VoltRoute',
                'latitude': round(lat + rnd.uniform(-0.05, 0.05), 4),
                'longitude': round(lon + rnd.uniform(-0.05, 0.05), 4),
                'max_power_kw': float(rnd.choice([50, 150, 350])),
                'num_connectors': rnd.choice([2, 4, 6, 8]),
                'tariff_per_kwh': round(rnd.uniform(12, 22), 1),
                'status': 'MAINTENANCE' if n in (5, 12) else 'ACTIVE',
            })
    return stations  # 16 stations, 5 cities, 2 in maintenance