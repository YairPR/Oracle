"""Versioned report state: SQL facts plus complete episode data, no source reads."""

import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import duckdb

SCHEMA_VERSION = 4


def runtime_metadata():
    root = Path(__file__).resolve().parents[2]
    try:
        commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True, stderr=subprocess.DEVNULL
        ).strip()
        dirty = bool(
            subprocess.check_output(
                ["git", "status", "--porcelain", "--untracked-files=no"],
                cwd=root,
                text=True,
            )
        )
    except (OSError, subprocess.CalledProcessError):
        commit, dirty = "sin-git", False
    sources = [
        root / "Analizer" / "analizador.py",
        Path(__file__).with_name("storage.py"),
    ]
    analyzer = root / "Analizer"
    files = [
        *analyzer.glob("*.py"),
        *analyzer.glob("core/*.py"),
        *analyzer.glob("parsers/*.py"),
        *analyzer.glob("ai/*.py"),
        *analyzer.glob("templates/*.html"),
        analyzer / "templates/static/theme.css",
        analyzer / "templates/static/dashboard.bundle.js",
    ]
    digest = hashlib.sha256()
    for path in sorted(files):
        digest.update(str(path.relative_to(analyzer)).encode())
        digest.update(path.read_bytes())
    return {
        "codigo_sha256": digest.hexdigest(),
        "commit": commit,
        "dirty": dirty,
        "python": sys.version.split()[0],
        "duckdb": duckdb.__version__,
        "fuentes": [
            {
                "ruta": str(p.resolve()),
                "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
            }
            for p in sources
        ],
        "zona_horaria": "No declarada: hora local del archivo conservada sobre eje UTC neutro.",
        "muestra_unica_margen_seg": 1,
    }


def dataset_signature(con):
    """Detect stale derived data without reading any source file."""
    result = {}
    for table in [
        "fact_telemetria_so",
        "fact_awr_snapshots",
        "fact_awr_wait_events",
        "dim_database",
        "dim_infraestructura",
    ]:
        columns = [
            row[0]
            for row in con.execute(f"DESCRIBE {table}").fetchall()
            if row[0] not in {"creado_en", "actualizado_en"}
        ]
        count, checksum = con.execute(
            f"SELECT count(*), bit_xor(hash({', '.join(columns)})) FROM {table}"
        ).fetchone()
        result[table] = [count, checksum]
    if con.execute("SELECT count(*) FROM duckdb_tables() WHERE table_name='oclumon_sources'").fetchone()[0]:
        result['oclumon_sources']=list(con.execute('SELECT count(*), bit_xor(hash(source, diagnostic, observations)) FROM oclumon_sources').fetchone())
    return result


def save_report_state(db, episodes, ingestion, context):
    from core.html_builder import compactar_payload_wire

    compact = compactar_payload_wire({"motor_episodios": episodes})["motor_episodios"]
    runtime = episodes.get("version_ingesta") or runtime_metadata()
    compact["version_ingesta"] = runtime
    data = {
        "version": SCHEMA_VERSION,
        "complete": not ingestion.get("errores") and not episodes.get("error_motor"),
        "context": context,
        "episodes": compact,
        "ingestion": ingestion,
        "runtime": runtime,
    }
    with duckdb.connect(db) as con:
        data["dataset_signature"] = dataset_signature(con)
        blob = gzip.compress(
            json.dumps(
                data, ensure_ascii=False, allow_nan=False, separators=(",", ":")
            ).encode(),
            compresslevel=1,
        )
        con.execute(
            "CREATE TABLE IF NOT EXISTS report_state (id INTEGER PRIMARY KEY, version INTEGER, data BLOB)"
        )
        con.execute("BEGIN")
        try:
            con.execute("DELETE FROM report_state")
            con.execute(
                "INSERT INTO report_state VALUES (1, ?, ?)", [SCHEMA_VERSION, blob]
            )
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise
    return compact


def load_report_state(db):
    if not Path(db).is_file():
        raise ValueError(
            "No existe la base persistida; ejecute primero la ingesta completa."
        )
    with duckdb.connect(db, read_only=True) as con:
        try:
            signature = dataset_signature(con)
            row = con.execute(
                "SELECT version, data FROM report_state WHERE id=1"
            ).fetchone()
        except duckdb.Error as exc:
            raise ValueError(
                "La base no contiene episodios persistidos; ejecute una ingesta con esta versión."
            ) from exc
    if not row or row[0] != SCHEMA_VERSION:
        raise ValueError(
            "Estado persistido ausente o incompatible; no se genera un informe incompleto."
        )
    data = json.loads(gzip.decompress(bytes(row[1])))
    if data.get("version") != SCHEMA_VERSION or "episodes" not in data:
        raise ValueError("Estado de reporte incompatible.")
    if data.get("dataset_signature") != signature:
        raise ValueError(
            "Los datos SQL cambiaron desde el análisis persistido; ejecute una ingesta completa."
        )
    if not isinstance(data.get("context"), dict):
        raise ValueError(
            "Falta el contexto SQL persistido; no se genera un informe incompleto."
        )
    if not data.get("complete"):
        raise ValueError(
            "La ingesta persistida tuvo errores; no se genera un informe incompleto silenciosamente."
        )
    return data
