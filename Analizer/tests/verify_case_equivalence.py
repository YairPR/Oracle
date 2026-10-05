"""Compare SQL facts and every original telemetry point against the compact HTML."""

import argparse
import hashlib
import json
from pathlib import Path
import duckdb

ap = argparse.ArgumentParser()
ap.add_argument("before")
ap.add_argument("after")
ap.add_argument("out")
args = ap.parse_args()


def payload(folder):
    text = (Path(folder) / "informe_incidente.html").read_text(encoding="utf-8")
    encoded = text.split("<script>\nwindow.__PAYLOAD__ = ", 1)[1].split(
        ";\n</script>", 1
    )[0]
    return json.loads(encoded.replace("<\\/", "</"))


old, new = payload(args.before), payload(args.after)
a, b = old["motor_episodios"], new["motor_episodios"]
for key in [
    "node_list",
    "nic_types",
    "nic_names_by_type",
    "episodios",
    "eventos_discretos",
    "linea_tiempo",
    "proc_rankings",
    "series_max",
    "device_names",
    "device_names_vistos_total",
    "filesystem_mounts",
]:
    assert a.get(key) == b.get(key), key
series_count = points_count = null_count = flags_count = 0
for node, metrics in a["series_por_nodo"].items():
    assert set(metrics) == set(b["series_por_nodo"][node])
    for name, points in metrics.items():
        encoded = b["series_por_nodo"][node][name]
        if not points:
            assert not encoded
            continue
        clock = b["series_timestamps"][encoded["clock"]]
        assert len(clock) == len(points)
        nulls = set(encoded.get("nulls", []))
        flags = set(encoded.get("lt", []))
        for i, p in enumerate(points):
            value = (
                None
                if i in nulls
                else (
                    encoded["values"][i] if "values" in encoded else encoded["constant"]
                )
            )
            assert p[0] == clock[i] and p[1] == value, (node, name, i)
            assert bool(p[2] if len(p) > 2 else 0) == (i in flags)
            null_count += value is None
            flags_count += i in flags
        series_count += 1
        points_count += len(points)
tables = {}
left = duckdb.connect(str(Path(args.before) / "case.duckdb"), read_only=True)
right = duckdb.connect(str(Path(args.after) / "case.duckdb"), read_only=True)
for table in [
    "fact_telemetria_so",
    "fact_awr_snapshots",
    "fact_awr_wait_events",
    "dim_database",
    "dim_infraestructura",
]:
    cols = [
        r[0]
        for r in left.execute("DESCRIBE " + table).fetchall()
        if r[0] not in {"creado_en", "actualizado_en"}
    ]
    query = "SELECT " + ", ".join(cols) + " FROM " + table + " ORDER BY ALL"
    rows = left.execute(query).fetchall()
    assert rows == right.execute(query).fetchall(), table
    tables[table] = {
        "count": len(rows),
        "sha256": hashlib.sha256(
            json.dumps(rows, default=str, ensure_ascii=False).encode()
        ).hexdigest(),
    }
result = {
    "all_values_equal": True,
    "series": series_count,
    "points_including_gaps": points_count,
    "null_gaps": null_count,
    "less_than_flags": flags_count,
    "episodes": len(a["episodios"]),
    "tables": tables,
}
Path(args.out).write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result))
