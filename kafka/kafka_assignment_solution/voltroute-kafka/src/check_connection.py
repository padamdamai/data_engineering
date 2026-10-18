from confluent_kafka.admin import AdminClient
from common import kafka_conf, sr_client

md = AdminClient(kafka_conf()).list_topics(timeout=10)
print('Kafka OK. Topics:', sorted(md.topics.keys()))
print('Schema Registry OK. Subjects:', sr_client().get_subjects())