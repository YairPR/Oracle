"""Compare identical persisted records, conversion + execute + commit + index rebuild."""

import argparse
import gc
import math
import json
from pathlib import Path
import sys
import time
import threading

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import duckdb
import pandas as pd
import pyarrow as pa
import psutil
from core.storage import DDL_FACT_TELEMETRIA_SO

ap = argparse.ArgumentParser()
ap.add_argument("db")
ap.add_argument("out")
args = ap.parse_args()
source = duckdb.connect(args.db, read_only=True)
rows = source.execute("SELECT * FROM fact_telemetria_so ORDER BY ALL").fetchall()
names = [c[0] for c in source.description]
schema = pa.schema(
    [
        (n, t)
        for n, t in zip(
            names,
            [
                pa.string(),
                pa.timestamp("us"),
                pa.string(),
                pa.string(),
                pa.string(),
                pa.float64(),
                pa.string(),
            ],
        )
    ]
)
expected = source.execute(
    "SELECT count(*), sum(valor), count(valor) FROM fact_telemetria_so"
).fetchone()
indices = [
    f"CREATE INDEX idx_{c} ON fact_telemetria_so({c})"
    for c in ["timestamp", "nodo", "fuente"]
]
results = []
for method in ["unnest", "arrow", "dataframe"]:
    for batch in [1000, 5000, 20000]:
        for deferred in [False, True]:
            for repeat in range(3):
                gc.collect()
                con = duckdb.connect()
                con.execute(DDL_FACT_TELEMETRIA_SO)
                if not deferred:
                    for sql in indices:
                        con.execute(sql)
                rss = psutil.Process().memory_info().rss
                peak = [rss]
                stop = threading.Event()

                def monitor():
                    while not stop.wait(0.002):
                        peak[0] = max(peak[0], psutil.Process().memory_info().rss)

                thread = threading.Thread(target=monitor, daemon=True)
                thread.start()
                start = time.perf_counter()
                conversion = execution = 0
                con.execute("BEGIN")
                for i in range(0, len(rows), batch):
                    chunk = rows[i : i + batch]
                    t = time.perf_counter()
                    columns = [list(col) for col in zip(*chunk)]
                    if method == "arrow":
                        data = pa.Table.from_arrays(
                            [
                                pa.array(col, type=field.type)
                                for col, field in zip(columns, schema)
                            ],
                            schema=schema,
                        )
                    elif method == "dataframe":
                        data = pd.DataFrame(dict(zip(names, columns)))
                    conversion += time.perf_counter() - t
                    t = time.perf_counter()
                    if method == "unnest":
                        con.execute(
                            "INSERT INTO fact_telemetria_so SELECT "
                            + ", ".join("unnest(?)" for _ in names),
                            columns,
                        )
                    else:
                        con.register("batch_data", data)
                        con.execute(
                            "INSERT INTO fact_telemetria_so SELECT * FROM batch_data"
                        )
                        con.unregister("batch_data")
                    execution += time.perf_counter() - t
                t = time.perf_counter()
                con.execute("COMMIT")
                commit = time.perf_counter() - t
                t = time.perf_counter()
                if deferred:
                    for sql in indices:
                        con.execute(sql)
                rebuild = time.perf_counter() - t
                total = time.perf_counter() - start
                stop.set()
                thread.join()
                actual = con.execute(
                    "SELECT count(*), sum(valor), count(valor) FROM fact_telemetria_so"
                ).fetchone()
                assert (
                    actual[0] == expected[0]
                    and actual[2] == expected[2]
                    and math.isclose(
                        actual[1], expected[1], rel_tol=1e-12, abs_tol=1e-4
                    )
                )
                # Full row multiset equality includes timestamps, NULLs and floating point precision.
                assert (
                    con.execute(
                        "SELECT * FROM fact_telemetria_so ORDER BY ALL"
                    ).fetchall()
                    == rows
                )
                results.append(
                    dict(
                        method=method,
                        batch=batch,
                        deferred_indices=deferred,
                        repeat=repeat,
                        conversion_seg=conversion,
                        execution_seg=execution,
                        commit_seg=commit,
                        rebuild_seg=rebuild,
                        total_seg=total,
                        peak_rss_delta_bytes=peak[0] - rss,
                        rows=len(rows),
                    )
                )
                con.close()
Path(args.out).write_text(json.dumps(results, indent=2), encoding="utf-8")
print("54 comparisons: exact equality OK")
