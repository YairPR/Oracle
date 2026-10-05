"""Compact original OCLUMON blocks, retained in DuckDB rather than duplicated in HTML."""

import gzip
import json
import io
import time


def save(con, source, samples, diagnostic):
    started = time.perf_counter()
    con.execute(
        "CREATE TABLE IF NOT EXISTS oclumon_sources (source VARCHAR PRIMARY KEY, diagnostic JSON, observations BLOB)"
    )
    sql_seconds = time.perf_counter() - started
    started = time.perf_counter()
    buffer = io.BytesIO()
    with gzip.GzipFile(
        fileobj=buffer, mode="wb", compresslevel=1, mtime=0
    ) as compressed:
        compressed.write(b"[")
        for i, sample in enumerate(samples):
            if i:
                compressed.write(b",")
            data = {**sample, "clock": sample["clock"].isoformat()}
            compressed.write(
                json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode()
            )
        compressed.write(b"]")
    blob = buffer.getvalue()
    diag = json.dumps(
        diagnostic,
        default=lambda x: sorted(x) if isinstance(x, set) else x.isoformat(),
        ensure_ascii=False,
    )
    serialization_seconds = time.perf_counter() - started
    started = time.perf_counter()
    con.execute(
        "INSERT OR REPLACE INTO oclumon_sources VALUES (?, ?, ?)",
        [str(source), diag, blob],
    )
    sql_seconds += time.perf_counter() - started
    # Raw fields now live in the durable blob; analytical entities remain in
    # memory for episodes. Avoid retaining all process rows for every source.
    for sample in samples:
        sample["records"] = []
    return {"serializar_fuente_seg": serialization_seconds, "sql_fuente_seg": sql_seconds}


def load(con, source):
    row = con.execute(
        "SELECT observations FROM oclumon_sources WHERE source=?", [str(source)]
    ).fetchone()
    return json.loads(gzip.decompress(bytes(row[0]))) if row else []
