"""Regression contracts for single parsing, report-only and lossless wire data."""

import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import duckdb
import analizador
from core.episode_engine import parse_oclumon_file, _detectar_ventanas_captura
from core.html_builder import compactar_payload_wire
from core.report_state import load_report_state
from core.storage import ForensicStorage


class Contracts(unittest.TestCase):
    def test_wire_roundtrip(self):
        points = [[1, 4], [2, None], [10, 4, 1]]
        payload = {
            "motor_episodios": {
                "series_por_nodo": {
                    "n": {"a": points, "b": [[1, 2], [2, None], [10, 9]]}
                }
            }
        }
        original = copy.deepcopy(payload)
        wire = compactar_payload_wire(payload)
        self.assertEqual(payload, original)
        self.assertEqual(len(wire["motor_episodios"]["series_timestamps"]), 1)
        for name, encoded in wire["motor_episodios"]["series_por_nodo"]["n"].items():
            times = wire["motor_episodios"]["series_timestamps"][encoded["clock"]]
            decoded = [
                [
                    t,
                    None
                    if i in encoded.get("nulls", [])
                    else encoded.get("values", [encoded.get("constant")] * len(times))[
                        i
                    ],
                ]
                + ([1] if i in encoded.get("lt", []) else [])
                for i, t in enumerate(times)
            ]
            self.assertEqual(
                decoded, original["motor_episodios"]["series_por_nodo"]["n"][name]
            )

    def test_one_parse_and_report_only(self):
        with tempfile.TemporaryDirectory() as temp:
            db = str(Path(temp) / "test.duckdb")
            html = str(Path(temp) / "report.html")
            case = str(Path(__file__).parent)
            with patch(
                "core.episode_engine.parse_oclumon_file", wraps=parse_oclumon_file
            ) as parse:
                first = analizador.ejecutar_caso_completo(
                    case, db, log_cb=lambda s: None, salida=html
                )
                self.assertEqual(parse.call_count, 1)
            con = duckdb.connect(db, read_only=True)
            before = con.execute(
                "SELECT * FROM fact_telemetria_so ORDER BY ALL"
            ).fetchall()
            con.close()
            with (
                patch(
                    "analizador.ingerir_carpeta",
                    side_effect=AssertionError("must not ingest"),
                ),
                patch(
                    "core.episode_engine.parse_oclumon_file",
                    side_effect=AssertionError("must not read CHM"),
                ),
            ):
                second = analizador.ejecutar_caso_completo(
                    case, db, log_cb=lambda s: None, solo_reporte=True, salida=html
                )
            self.assertEqual(
                first["resultado_episodios"], second["resultado_episodios"]
            )
            con = duckdb.connect(db, read_only=True)
            self.assertEqual(
                before,
                con.execute("SELECT * FROM fact_telemetria_so ORDER BY ALL").fetchall(),
            )
            con.close()
            text = Path(html).read_text(encoding="utf-8")
            self.assertIn("Hardware y fuentes", text)
            self.assertNotIn('id="odl-rango-nodos"', text)
            con = duckdb.connect(db)
            con.execute(
                "UPDATE fact_telemetria_so SET valor=valor+1 WHERE metrica_o_error='CPU_USAGE_PCT'"
            )
            con.close()
            with self.assertRaisesRegex(ValueError, "datos SQL cambiaron"):
                load_report_state(db)

    def test_old_database_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            db = str(Path(temp) / "old.duckdb")
            duckdb.connect(db).close()
            with self.assertRaisesRegex(ValueError, "episodios persistidos"):
                load_report_state(db)

    def test_bulk_rollback(self):
        with tempfile.TemporaryDirectory() as temp:
            with ForensicStorage(str(Path(temp) / "rollback.duckdb")) as storage:
                good = {
                    "timestamp": "2026-09-30T02:35:04",
                    "nodo": "n",
                    "fuente": "oclumon",
                    "metrica_o_error": "CPU",
                    "valor": 0.125,
                }
                storage.bulk_insert_telemetria("case", [good])
                broken = {**good, "valor": "not-a-number"}
                with self.assertRaises(duckdb.Error):
                    storage.bulk_insert_telemetria("case", [good] * 20000 + [broken])
                self.assertEqual(
                    storage.con.execute(
                        "SELECT count(*), sum(valor) FROM fact_telemetria_so"
                    ).fetchone(),
                    (1, 0.125),
                )
                with self.assertRaises(ValueError):
                    storage.bulk_insert_telemetria(
                        "case", [{**good, "timestamp": "bad"}]
                    )
                self.assertEqual(
                    storage.con.execute(
                        "SELECT count(*) FROM fact_telemetria_so"
                    ).fetchone()[0],
                    1,
                )
                def fail_originals(con):
                    con.execute('CREATE TABLE temporary_originals(value INTEGER)')
                    raise RuntimeError('cannot persist originals')
                with self.assertRaisesRegex(RuntimeError,'persist originals'):
                    storage.bulk_insert_telemetria('case',[good],observation_callback=fail_originals)
                self.assertEqual(storage.con.execute('SELECT count(*) FROM fact_telemetria_so').fetchone()[0],1)
                self.assertEqual(storage.con.execute("SELECT count(*) FROM duckdb_tables() WHERE table_name='temporary_originals'").fetchone()[0],0)


if __name__ == "__main__":
    unittest.main()
