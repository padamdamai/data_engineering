"""explain(executionStats) evidence, BEFORE and AFTER each index (Part D)."""
import os
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import OperationFailure

from app import pipelines
from create_indexes import INDEXES

load_dotenv()
db = MongoClient(os.environ["MONGODB_URI"])[os.getenv("MONGODB_DB", "cinebook")]

CASES = [
    {
        "title": "1. Browse shows: Dune in Delhi from 10 Nov, sorted by time",
        "index": "shows_city_movie_start",
        "explain": {
            "find": "shows",
            "filter": {"city": "Delhi", "movie_id": "MOV-DUNE2",
                       "start_time": {"$gte": datetime(2026, 11, 10, tzinfo=timezone.utc)}},
            "sort": {"start_time": 1},
            "projection": {"seats": 0},
        },
    },
    {
        "title": "2. A user's bookings, newest first",
        "index": "bookings_user_created",
        "explain": {
            "find": "bookings",
            "filter": {"user_id": "USR-1001"},
            "sort": {"created_at": -1},
        },
    },
    {
        "title": "3. Revenue per movie (aggregation on bookings)",
        "index": "bookings_status_movie",
        "explain": {"aggregate": "bookings",
                    "pipeline": pipelines.revenue_per_movie(), "cursor": {}},
    },
    {
        "title": "4. Occupancy per show in Delhi (aggregation on shows)",
        "index": "shows_city_movie_start",
        "explain": {"aggregate": "shows",
                    "pipeline": pipelines.occupancy_per_show("Delhi"), "cursor": {}},
    },
]


def walk(node, out):
    """Collect plan stage names, top to bottom (IXSCAN also shows its index name)."""
    if isinstance(node, dict):
        if "stage" in node:
            name = node["stage"]
            if name == "IXSCAN":
                name += f"({node.get('indexName')})"
            out.append(name)
        for key in ("inputStage", "queryPlan"):
            if key in node:
                walk(node[key], out)
        for child in node.get("inputStages", []):
            walk(child, out)
    return out


def summarize(res):
    stages = res.get("stages") or []
    if stages and "$cursor" in stages[0]:
        cur = stages[0]["$cursor"]
        qp, es = cur.get("queryPlanner", {}), cur.get("executionStats", {})
        later = [next(iter(s)) for s in stages[1:]]
    else:
        qp, es = res.get("queryPlanner", {}), res.get("executionStats", {})
        later = [next(iter(s)) for s in stages[1:]]
    chain = walk(qp.get("winningPlan", {}), [])
    return {
        "plan": " > ".join(chain),
        "has_sort": "SORT" in chain,
        "docs": es.get("totalDocsExamined", "?"),
        "keys": es.get("totalKeysExamined", "?"),
        "returned": es.get("nReturned", "?"),
        "ms": es.get("executionTimeMillis", "?"),
        "later": later,
    }


def explain(spec):
    return db.command({"explain": spec, "verbosity": "executionStats"})


def recreate(index_name):
    for coll, keys, name in INDEXES:
        if name == index_name:
            db[coll].create_index(keys, name=name)


def line(label, s):
    sort_txt = "YES (in-memory SORT)" if s["has_sort"] else "no"
    text = (f"  {label}: {s['plan']}\n"
            f"           docs examined={s['docs']}  keys examined={s['keys']}  "
            f"returned={s['returned']}  time={s['ms']} ms  in-memory sort: {sort_txt}")
    if s["later"]:
        text += f"\n           later pipeline stages: {', '.join(s['later'])}"
    return text


if __name__ == "__main__":
    report = []
    for case in CASES:
        index = case["index"]
        coll = next(c for c, _, n in INDEXES if n == index)
        try:
            db[coll].drop_index(index)
        except OperationFailure:
            pass                                    # index was already missing
        try:
            before = summarize(explain(case["explain"]))
        finally:
            recreate(index)
        after = summarize(explain(case["explain"]))

        block = [case["title"], f"  index under test: {index}",
                 line("BEFORE (no index)", before), line("AFTER  (with index)", after), ""]
        report += block
        print("\n".join(block))

    with open(os.path.join(ROOT, "explain_report.md"), "w") as f:
        f.write("```\n" + "\n".join(report) + "\n```\n")
    print("Saved to explain_report.md")