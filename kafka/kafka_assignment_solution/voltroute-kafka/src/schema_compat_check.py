import json
import sys
from confluent_kafka.schema_registry import Schema
from common import sr_client, read_schema

SUBJECT = 'session_start-value'
sr = sr_client()


def clone(d):
    return json.loads(json.dumps(d))


def candidates():
    base = json.loads(read_schema('schemas/session_start_v1.avsc'))
    add_default = clone(base)
    add_default['fields'].append({'name': 'payment_method', 'type': 'string', 'default': 'UNKNOWN'})
    add_no_default = clone(base)
    add_no_default['fields'].append({'name': 'loyalty_tier', 'type': 'string'})
    removed = clone(base)
    removed['fields'] = [f for f in removed['fields'] if f['name'] != 'user_id']
    return [
        ('ADD payment_method WITH a default', add_default),
        ('ADD loyalty_tier WITHOUT a default', add_no_default),
        ('REMOVE the user_id field', removed),
    ]


def status():
    sr.set_compatibility(SUBJECT, 'BACKWARD')
    print('Compatibility mode of', SUBJECT, '=', sr.get_compatibility(SUBJECT))
    for v in sr.get_versions(SUBJECT):
        rs = sr.get_version(SUBJECT, v)
        names = [f['name'] for f in json.loads(rs.schema.schema_str)['fields']]
        print('  version', rs.version, '| schema id', rs.schema_id, '| fields:', ', '.join(names))


def test():
    for label, schema_dict in candidates():
        ok = sr.test_compatibility(SUBJECT, Schema(json.dumps(schema_dict), 'AVRO'))
        print('ACCEPTED' if ok else 'REJECTED', '-', label)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        test()
    else:
        status()