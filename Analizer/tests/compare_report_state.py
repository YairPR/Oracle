"""Compare every observed series point and episode after representation changes."""

import argparse
import gc
import gzip
import hashlib
import itertools
import json
from pathlib import Path
import duckdb

ap = argparse.ArgumentParser()
ap.add_argument("before")
ap.add_argument("after")
ap.add_argument("out")
args = ap.parse_args()


def fingerprint(path):
    with duckdb.connect(path, read_only=True) as con:
        blob = con.execute("SELECT data FROM report_state WHERE id=1").fetchone()[0]
    data = json.loads(gzip.decompress(bytes(blob)))["episodes"]
    result = {}
    for node, metrics in data["series_por_nodo"].items():
        for name, encoded in metrics.items():
            if isinstance(encoded, dict):
                times = data["series_timestamps"][encoded["clock"]]
                nulls = set(encoded.get("nulls", []))
                flags = set(encoded.get("lt", []))
                values = encoded.get("values")
                values = (
                    values
                    if values is not None
                    else itertools.repeat(encoded.get("constant"))
                )
                observed = [
                    (t, v, i in flags)
                    for i, (t, v) in enumerate(zip(times, values))
                    if v is not None and i not in nulls
                ]
            else:
                observed = [
                    (p[0], p[1], bool(len(p) > 2 and p[2]))
                    for p in encoded
                    if p[1] is not None
                ]
            result[(node, name)] = hashlib.sha256(
                json.dumps(observed, separators=(",", ":")).encode()
            ).hexdigest()
    for key in ("episodios", "linea_tiempo", "ventanas_captura"):
        result[key] = hashlib.sha256(
            json.dumps(data[key], sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
    return result


before = fingerprint(args.before)
gc.collect()
after = fingerprint(args.after)
assert before == after, [
    str(k) for k in set(before) | set(after) if before.get(k) != after.get(k)
]
result = {
    "equal": True,
    "series_count": len(before) - 3,
    "every_observed_value_time_and_bound_preserved": True,
    "episodes_timeline_captures_equal": True,
}
Path(args.out).write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result))
