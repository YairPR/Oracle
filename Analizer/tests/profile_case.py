"""Reproducible full-case measurements; never writes into the evidence folder."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import threading
import time

ap = argparse.ArgumentParser()
ap.add_argument("case")
ap.add_argument("out")
ap.add_argument("--source", default=str(Path(__file__).resolve().parents[1]))
ap.add_argument("--provenance", help="Explicit collector metadata manifest")
args = ap.parse_args()
sys.path.insert(0, args.source)
import duckdb
import psutil
import analizador as a
from core.storage import ForensicStorage
from core.source_provenance import load_manifest

out = Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)
peak = [0]
stop = threading.Event()


def monitor():
    while not stop.wait(0.02):
        peak[0] = max(peak[0], psutil.Process().memory_info().rss)


thread = threading.Thread(target=monitor, daemon=True)
thread.start()
original = a.generar_reporte_html


def render(db, context, case, **kwargs):
    payload = a.construir_payload(db, context, case, kwargs.get("resultado_episodios"))
    blocks = {
        k: len(json.dumps(v, ensure_ascii=False, separators=(",", ":")).encode())
        for k, v in payload.items()
    }
    (out / "payload-blocks.json").write_text(
        json.dumps(blocks, indent=2), encoding="utf-8"
    )
    html = a.render_dashboard(payload)
    path = out / "informe_incidente.html"
    path.write_text(html, encoding="utf-8")
    return str(path)


a.generar_reporte_html = render
start = time.perf_counter()
try:
    result = a.ejecutar_caso_completo(
        args.case, str(out / "case.duckdb"), log_cb=lambda s: print(s, flush=True),
        source_provenance=load_manifest(args.provenance, args.case) if args.provenance else None,
    )
finally:
    stop.set()
    thread.join()
con = duckdb.connect(str(out / "case.duckdb"), read_only=True)
tables = {}
for name in [
    "fact_telemetria_so",
    "fact_awr_snapshots",
    "fact_awr_wait_events",
    "dim_database",
    "dim_infraestructura",
]:
    columns = [
        row[0]
        for row in con.execute(f"DESCRIBE {name}").fetchall()
        if row[0] not in {"creado_en", "actualizado_en"}
    ]
    rows = con.execute(
        f"SELECT {', '.join(columns)} FROM {name} ORDER BY ALL"
    ).fetchall()
    tables[name] = {
        "count": len(rows),
        "sha256": hashlib.sha256(
            json.dumps(rows, default=str, ensure_ascii=False).encode()
        ).hexdigest(),
    }
metrics = {
    "python": sys.version,
    "duckdb": duckdb.__version__,
    "analizador": a.__file__,
    "storage": sys.modules["core.storage"].__file__,
    "wall_seg": time.perf_counter() - start,
    "peak_rss_bytes": peak[0],
    "html_bytes": (out / "informe_incidente.html").stat().st_size,
    "phases": result["tiempos_fases"],
    "ingestion": result["resumen_ingesta"]["tiempos"],
    "tables": tables,
    "episodes": len(result["resultado_episodios"]["episodios"]),
}
(out / "metrics.json").write_text(
    json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8"
)
print(json.dumps(metrics, ensure_ascii=False), flush=True)
