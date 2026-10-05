"""Adapter, semantic and provenance regressions; real evidence enabled by env vars."""

import os
from pathlib import Path
import tempfile
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.oclumon_model import parse
from core.oclumon_dataset import deduplicate, build
from core.episode_engine import (
    analizar_caso,
    detect_anomalias,
    build_episodios,
    _series_proto_delta_nodo,
    _insertar_huecos,
    _process_series,
)
from core.router import LogRouter
from parsers.base import LogType


def block(
    host="host4",
    stamp="2026-10-05 10.30.00+0200",
    cpu="12.59",
    counter="50",
    wait="1200",
):
    return f"""Node: {host} Clock: '{stamp}' SerialNo:1
SYSTEM:
"cpuusage[%]","#vcpus","#pcpus","#cores","physmemtotal[KB]","physmemfree[KB]","memavl[KB]","#cpuq","swpin[KB/s]","swpout[KB/s]","nicErrors[#/s]","extra"
{cpu},18,9,18,205768192,N/C,99329008,0,0,0,0,"a,b"
DEVICE:
"wait[msec]","diskname","ios[#/s]","type","ior[KB/s]","iow[KB/s]","#qlen"
{wait},"diskA",10,"DISK",100,50,0
2,"diskB",5,"PARTITION",20,5,0
NIC:
"id/name","errsin[#/s]","errsout[#/s]","netrr[KB/s]","netwr[KB/s]","type","latency[msec]"
"eth0",0,0,1.5,2.5,"PRIVATE",<1
FILESYSTEM:
"mount","type","total[KB]","used[KB]","available[KB]","used[%]"
"/data","xfs",20314748,15859432,3406740,82
"/","rootfs",0,0,0,0
PROTOCOLS:
"RetraSegErr[#]","FailedConnErr[#]"
100,4
"ReasFailErr[#]","HdrErr[#]"
{counter},0
NFS:
"mountpoint","devicename"
"""


class FormatTests(unittest.TestCase):
    def test_format_is_independent_of_extension_and_collector_version(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "legacy.csv"
            path.write_text(
                "Node: old Clock: '09-30-26 02.35.04' SerialNo:1\nSYSTEM:\ncpu: 2 physmemfree: 0\n",
                encoding="utf-8",
            )
            samples, diagnostic, _ = parse(path)
            self.assertEqual(diagnostic["formats"], {"legacy"})
            self.assertEqual(diagnostic["source_metadata"], {})
            self.assertEqual(samples[0]["sys"]["cpu"], 2)
            path = Path(directory) / "sections.txt"
            path.write_text(block(), encoding="utf-8")
            _, diagnostic, _ = parse(path)
            self.assertEqual(diagnostic["formats"], {"csv-sections"})
            self.assertEqual(diagnostic["source_metadata"], {})

    def test_process_absences_keep_boundaries_and_all_observations(self):
        values = [None, None, None, 0, None, None, 9, None, None]
        rows = [{"process_metrics": {"oracle": {"max_cpuusage": v}}} for v in values]
        points = _process_series(rows, list(range(9)), "oracle", "max_cpuusage")
        self.assertEqual(
            points, [{"t": t, "v": values[t]} for t in [0, 2, 3, 4, 5, 6, 7, 8]]
        )
        self.assertEqual([p["v"] for p in points if p["v"] is not None], [0, 9])
        from core.dashboard_engine import _has_observed

        self.assertFalse(_has_observed({"clock": "0", "values": [None, None]}))
        self.assertTrue(_has_observed({"clock": "0", "constant": 0}))

    def test_explicit_provenance_requires_evidence_and_never_sets_database_version(
        self,
    ):
        from core.source_provenance import load_manifest, source_key
        import json

        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "metadata.json"
            manifest.write_text(
                json.dumps(
                    {
                        "sources": {
                            "sections.txt": {
                                "collector_version": "19c",
                                "collector_evidence": "User statement",
                                "database_version": "invented",
                            }
                        }
                    }
                ),
                encoding="utf-8",
            )
            entry = load_manifest(manifest, directory)[
                source_key(Path(directory) / "sections.txt")
            ]
            self.assertEqual(entry["collector_version"], "19c")
            self.assertNotIn("database_version", entry)
            manifest.write_text(
                json.dumps({"sources": {"sections.txt": {"collector_version": "19c"}}}),
                encoding="utf-8",
            )
            with self.assertRaises(ValueError):
                load_manifest(manifest, directory)

    def test_process_maximum_is_per_interval_not_case_or_pid_sum(self):
        def with_process(stamp, first, second):
            return block(stamp=stamp).replace(
                "NFS:\n",
                'PROCESS:\n"pid","name","cpuusage[%]","privmem[KB]","#fd","#threads"\n'
                f'101,"oracle",{first},1024,20,2\n102,"oracle",{second},2048,30,3\nNFS:\n',
            )

        samples, diag, ranks = self.read(
            with_process("2026-10-05 10.30.00+0200", 90, 5)
            + with_process("2026-10-05 10.30.05+0200", 10, 20)
        )
        result = analizar_caso(
            ["source"], normalizados={"source": (samples, diag, ranks)}
        )
        points = result["series_por_nodo"]["host4"]["proc::oracle::max_cpuusage"]
        self.assertEqual([p["v"] for p in points], [90, 20])
        self.assertNotEqual(points[0]["t"], points[1]["t"])

    def test_source_without_private_interface(self):
        samples, diag, ranks = self.read(block().replace("PRIVATE", "CLUSTER,ASM"))
        result = analizar_caso(
            ["source"], normalizados={"source": (samples, diag, ranks)}
        )
        self.assertEqual(result["node_list"], ["host4"])
        self.assertTrue(
            all(
                p["v"] is None
                for p in result["series_por_nodo"]["host4"]["interconnect_latency_ms"]
            )
        )

    def read(self, text):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "misleading_nodo1.bin"
            path.write_text(text, encoding="utf-8")
            self.assertEqual(LogRouter().detect_file_type(str(path)), LogType.OCLUMON)
            return parse(path)

    def test_csv_reordered_extra_and_nullable(self):
        samples, diag, _ = self.read(block())
        s = samples[0]
        self.assertEqual(diag["accepted"], 1)
        self.assertEqual(s["node"], "host4")
        self.assertEqual(s["sys"]["cpu"], 12.59)
        self.assertIsNone(s["sys"]["memfree_mb"])
        self.assertEqual(s["sys"]["memavl_mb"], 99329008 / 1024)
        self.assertEqual(s["inventory"]["pcpus"], 9)
        self.assertEqual(s["clock"].utcoffset().total_seconds(), 7200)
        self.assertEqual(s["clock"].timestamp(), 1791189000)
        self.assertEqual(s["devices"][0]["wait_ms"], 1200)
        self.assertEqual(s["proto"]["ipreasfail"], 50)
        self.assertEqual(s["proto"]["tcpretraseg"], 100)
        self.assertIsNone(s["filesystems"][1]["used_pct"])
        self.assertEqual(s["filesystems"][0]["used_pct"], 82)
        self.assertIn("nfs", diag["omitted_sections"])
        self.assertIn("extra", diag["sections"]["system"]["unknown_keys"])
        self.assertEqual(s["records"][0]["raw"]["extra"], "a,b")

    def test_multiple_hosts_and_unknown_zone(self):
        samples, diag, _ = self.read(block("host1") + block("host4"))
        self.assertEqual(diag["node_names"], {"host1", "host4"})
        legacy = "Node: legacy Clock: '09-30-26 02.35.04' SerialNo:2\nSYSTEM:\ncpu: 2 cpuq: 0\nphysmemtotal: 1024 physmemfree: 0\nFILESYSTEMS:\nmount: /data type: ext3 total: 20314748\nused: 15859432 available: 3406740 used%: 82\n"
        s, d, _ = self.read(legacy)
        self.assertIsNone(s[0]["clock"].tzinfo)
        self.assertEqual(s[0]["sys"]["memfree_mb"], 0)
        self.assertIsNone(s[0]["sys"]["memavl_mb"])
        self.assertEqual(s[0]["filesystems"][0]["used_pct"], 82)

    def test_zero_increment_reset_and_gap(self):
        text = "".join(
            block(stamp=f"2026-10-05 10.{m:02d}.{sec:02d}+0200", counter=str(value))
            for m, sec, value in [
                (30, 0, 50),
                (30, 15, 50),
                (30, 30, 53),
                (30, 45, 2),
                (40, 0, 5),
            ]
        )
        samples, _, _ = self.read(text)
        rows = build(samples)["host4"]
        values = [p["v"] for p in _series_proto_delta_nodo(rows)["ipreasfail"]]
        self.assertEqual(values, [None, 0, 3, None, None])
        self.assertEqual(rows[0]["cadence"], 15)
        self.assertNotEqual(rows[3]["segment"], rows[4]["segment"])
        self.assertEqual(rows[1]["nics_by_type"]["PRIVATE"]["errsin"], 0)
        events = detect_anomalias({"host4": rows})
        self.assertEqual([e["value"] for e in events if e["cat"] == "ip_reasfail"], [3])
        self.assertFalse(any(e["cat"] == "device_state" for e in events))

    def test_duplicate_entity_identity_and_conflict(self):
        samples, _, _ = self.read(block() + block())
        samples[1]["devices"][0]["wait_ms"] = 1300
        samples[1]["devices"].append({"name": "diskC", "wait_ms": 5})
        out, diag = deduplicate(samples)
        self.assertEqual(len(out), 1)
        self.assertEqual(len(out[0]["devices"]), 3)
        self.assertEqual(out[0]["devices"][0]["wait_ms"], 1200)
        self.assertTrue(any(c.get("field") == "wait_ms" for c in diag["conflicts"]))

    def test_peak_time_entity_quality_and_source(self):
        samples, _, _ = self.read(
            block(wait="1200")
            + block(stamp="2026-10-05 10.30.15+0200", wait="764641210")
        )
        episodes = build_episodios(detect_anomalias(build(samples)))
        ep = next(e for e in episodes if e["cat"] == "device_wait")
        self.assertNotEqual(ep["start"], ep["peak_time"])
        self.assertEqual(ep["entity"], "diskA")
        self.assertEqual(ep["quality"], "suspect")
        self.assertEqual(ep["peak_value"], 764641210)
        self.assertIsNotNone(ep["peak_line"])

    def test_conversion_failure_and_rejected_block(self):
        samples, diag, _ = self.read(block(cpu="bad"))
        self.assertIsNone(samples[0]["sys"]["cpu"])
        self.assertGreater(diag["quality_counts"]["conversion_error"], 0)
        samples, diag, _ = self.read(block(stamp="broken"))
        self.assertEqual(samples, [])
        self.assertEqual(diag["rejected"], 1)
        self.assertTrue(
            any("zero accepted" in d.get("msg", "") for d in diag["errors"])
        )

    def test_cadence_gap_not_fixed_five_seconds(self):
        points = [
            {"t": 0, "v": 0},
            {"t": 15, "v": 1},
            {"t": 30, "v": 2},
            {"t": 100, "v": 3},
        ]
        self.assertEqual(_insertar_huecos(points)[3], {"t": 45, "v": None})

    @unittest.skipUnless(
        os.environ.get("OCLUMON_CSV_CASE"), "set OCLUMON_CSV_CASE for real evidence"
    )
    def test_real_three_hosts(self):
        all_samples = []
        for host, cpu in [("03", 12.59), ("04", 15.37), ("07", 37.05)]:
            s, d, _ = parse(
                Path(os.environ["OCLUMON_CSV_CASE"]) / f"chm_nodo1_wdrac{host}.csv"
            )
            self.assertEqual(len(s), 721)
            self.assertEqual(d["rejected"], 0)
            self.assertFalse(d["errors"])
            self.assertEqual(s[0]["node"], f"bov-wdrac-{host}")
            self.assertEqual(s[0]["sys"]["cpu"], cpu)
            self.assertEqual(s[-1]["clock_raw"], "2026-10-05 11.30.00+0200")
            all_samples.extend(s)
        self.assertEqual(len(all_samples), 2163)
        self.assertEqual(len({s["clock"] for s in all_samples}), 721)

    @unittest.skipUnless(
        os.environ.get("OCLUMON_LEGACY_CASE"),
        "set OCLUMON_LEGACY_CASE for real evidence",
    )
    def test_real_extreme_and_capacity(self):
        root = Path(os.environ["OCLUMON_LEGACY_CASE"])
        samples, diag, _ = parse(root / "chm_nodo2_20261002_0530_1030_mtu.txt")
        match = next(
            (s, d) for s in samples for d in s["devices"] if d["wait_ms"] == 764641210
        )
        s, d = match
        self.assertEqual(s["clock"].isoformat(), "2026-10-02T09:54:16")
        self.assertEqual(d["name"], "xvdct")
        self.assertEqual(d["quality"], "suspect")
        self.assertTrue(
            any(
                f["mount"] == "/" and f["quality"] == "capacity_unavailable"
                for s in samples
                for f in s["filesystems"]
            )
        )


if __name__ == "__main__":
    unittest.main()
