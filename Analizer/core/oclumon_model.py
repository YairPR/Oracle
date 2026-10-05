"""Streaming CHM adapters. Original fields and source locations remain in the model."""

import csv
import re
import math
from datetime import datetime, timezone
from functools import lru_cache
from core.io_profile import TimedText

SECTIONS = {
    "SYSTEM": "system",
    "TOP CONSUMERS": "top",
    "TOPCONSUMERS": "top",
    "PROCESSES": "processes",
    "PROCESS": "processes",
    "CPU": "cpus",
    "DEVICES": "devices",
    "DEVICE": "devices",
    "NICS": "nics",
    "NIC": "nics",
    "FILESYSTEMS": "filesystems",
    "FILESYSTEM": "filesystems",
    "PROTOCOL ERRORS": "proto",
    "PROTOCOLS": "proto",
    "PROCESS AGGREGATE": "process_aggregate",
    "NFS": "nfs",
    "ADVM": "advm",
    "ASMINST_DB": "asminst_db",
}
UNIMPLEMENTED = {"process_aggregate", "nfs", "advm", "asminst_db"}
NODE = re.compile(r"Node:\s*(\S+)\s+Clock:\s*'([^']+)'(?:\s+SerialNo:\s*(\S+))?")
TOKEN = re.compile(r"([#A-Za-z][\w#%&]*)\s*:\s*('[^']*'|[^\s]+)")

KNOWN_FIELDS = {
    "system": {
        "cpu",
        "cpuq",
        "cpusys", "cpuuser", "cpuiowait", "cpusteal", "procs_blocked",
        "swpin",
        "swpout",
        "netr",
        "netw",
        "procs",
        "ior",
        "iow",
        "ios",
        "nicErrors",
        "physmemfree",
        "physmemtotal",
        "mcache",
        "swapfree",
        "swaptotal",
        "memavl",
        "#pcpus",
        "#cores",
        "#vcpus",
    },
    "top": {"topcpu", "topprivmem", "topshm", "topfd", "topthread"},
    "proto": {
        "IPHdrErr",
        "IPAddrErr",
        "IPUnkProto",
        "IPReasFail",
        "IPFragFail",
        "TCPFailedConn",
        "TCPEstRst",
        "TCPRetraSeg",
        "UDPUnkPort",
        "UDPRcvErr",
    },
    "nics": {
        "name",
        "netr",
        "netw",
        "neteff",
        "nicerrors",
        "pktsin",
        "pktsout",
        "errsin",
        "errsout",
        "indiscarded",
        "outdiscarded",
        "latency",
        "type",
        "mtu",
    },
    "devices": {"name", "ior", "iow", "ios", "qlen", "wait", "type"},
    "filesystems": {"mount", "type", "total", "used", "available", "used%", "ifree%"},
    "cpus": {"ID", "usage"},
    "processes": {"name", "pid", "cpu", "privmem", "shm", "#fd", "#threads"},
}


def clock(value):
    for fmt in ("%Y-%m-%d %H.%M.%S%z", "%Y-%m-%d %H.%M.%S", "%m-%d-%y %H.%M.%S"):
        try:
            return datetime.strptime(value.strip(), fmt)
        except ValueError:
            pass
    return None


@lru_cache(maxsize=1024)
def field_name(value):
    if value in ("used[%]", "ifree[%]"):
        return value.split("[")[0] + "%"
    name = value.split("[")[0].strip()
    aliases = {
        "cpuusage": "cpu",
        "#cpuq": "cpuq",
        "buffer&cache": "mcache",
        "#procs": "procs",
        "#procs_blocked": "procs_blocked",
        "netrr": "netr",
        "netwr": "netw",
        "#nicErrors": "nicErrors",
        "#qlen": "qlen",
        "diskname": "name",
        "id/name": "name",
        "privatemem": "privmem",
        "shmem": "shm",
        "#fds": "#fd",
        "topshmem": "topshm",
        "#topfd": "topfd",
        "#topthread": "topthread",
        "used": "used",
        "ifree": "ifree",
        "FailedConnErr": "TCPFailedConn",
        "EstRstErr": "TCPEstRst",
        "RetraSegErr": "TCPRetraSeg",
        "UnkPortErr": "UDPUnkPort",
        "RcvErr": "UDPRcvErr",
        "HdrErr": "IPHdrErr",
        "AddrErr": "IPAddrErr",
        "UnkProtoErr": "IPUnkProto",
        "ReasFailErr": "IPReasFail",
        "FragFailErr": "IPFragFail",
    }
    return aliases.get(name, name)


def number(raw, issues, field):
    if raw is None or str(raw).strip().upper() in ("", "N/A", "N/C", "NA", "-"):
        issues.append({"field": field, "raw": raw, "quality": "unavailable"})
        return None
    try:
        text = str(raw).lstrip("<>")
        annotation = re.match(r"^(\d+(?:\.\d+)?);", text) if field == "wait" else None
        if annotation:
            text = annotation.group(1)
            issues.append(
                {
                    "field": field,
                    "raw": raw,
                    "quality": "source_annotation",
                    "reason": "CHM appends a warning to its numeric wait field; numeric prefix retained",
                }
            )
        result = float(text)
        if not math.isfinite(result):
            raise ValueError("non-finite")
        return result
    except (ValueError, TypeError):
        issues.append({"field": field, "raw": raw, "quality": "conversion_error"})
        return None


def parse(path):
    diag = {
        "path": str(path),
        "source_metadata": {},
        "total_lines": 0,
        "samples": 0,
        "accepted": 0,
        "rejected": 0,
        "node_names": set(),
        "first_clock": None,
        "last_clock": None,
        "sections": {},
        "unparsed_samples": [],
        "errors": [],
        "formats": set(),
        "omitted_sections": {},
        "quality_counts": {},
        "lectura_seg": 0.0,
    }
    samples, ranks = [], {}
    cur = section = header = pending = None
    pending_line = 0

    def emit(section, fields, line):
        if cur is None:
            return
        sec = diag["sections"].setdefault(
            section,
            {
                "lines": 0,
                "matched": 0,
                "unmatched": 0,
                "unknown_keys": set(),
                "unknown_key_samples": {},
            },
        )
        sec["lines"] += 1
        if section in UNIMPLEMENTED:
            cur["records"].append(
                {
                    "line": line,
                    "section": section,
                    "raw": dict(fields),
                    "issues": [{"quality": "not_implemented"}],
                }
            )
            diag["omitted_sections"][section] = (
                "recognized; domain adapter not implemented"
            )
            sec["unmatched"] += 1
            return
        raw = dict(fields)
        # Names are section-specific: SYSTEM has netrr/netwr, NIC has netrr/netwr too.
        toks = {field_name(k): v for k, v in fields.items()}
        known = KNOWN_FIELDS.get(section, set())
        for key in set(toks) - known:
            sec["unknown_keys"].add(key)
            sec["unknown_key_samples"].setdefault(key, toks[key])
        if section == "nics":
            toks["netrr"] = toks.pop("netr", toks.get("netrr"))
            toks["netwr"] = toks.pop("netw", toks.get("netwr"))
        if section == "processes":
            toks["cpuusage"] = toks.pop("cpu", None)
        issues = []

        def n(key):
            return number(toks.get(key), issues, key)

        location = {"line": line, "section": section, "raw": raw, "issues": issues}
        cur["records"].append(location)
        if section == "system":
            keys = [
                "cpu",
                "cpuq",
                "swpin",
                "swpout",
                "netr",
                "netw",
                "procs",
                "ior",
                "iow",
                "ios",
            ]
            sys = {k: n(k) for k in keys}
            for key in ("cpusys", "cpuuser", "cpuiowait", "cpusteal", "procs_blocked"):
                if key in toks:
                    sys[key] = n(key)
            sys["nicerrors"] = n("nicErrors")
            for src, dest in [
                ("physmemfree", "memfree_mb"),
                ("physmemtotal", "memtotal_mb"),
                ("mcache", "mcache_mb"),
                ("swapfree", "swapfree_mb"),
                ("swaptotal", "swaptotal_mb"),
                ("memavl", "memavl_mb"),
            ]:
                val = n(src)
                sys[dest] = val / 1024 if val is not None else None
            cur["sys"] = sys
            cur["inventory"] = {
                "pcpus": n("#pcpus"),
                "cores": n("#cores"),
                "vcpus": n("#vcpus"),
                "ram_gib": sys["memtotal_mb"] / 1024
                if sys["memtotal_mb"] is not None
                else None,
            }
            for key, metric in [
                ("cpu", "CPU_USAGE_PCT"),
                ("ior", "IO_READ_RATE_KBPS"),
                ("iow", "IO_WRITE_RATE_KBPS"),
                ("ios", "IO_OPS_PER_SEC"),
                ("swpin", "SWAP_IN_KBPS"),
                ("swpout", "SWAP_OUT_KBPS"),
            ]:
                if sys[key] is not None:
                    cur["telemetria"].append((metric, sys[key]))
            if sys["swaptotal_mb"] is not None and sys["swapfree_mb"] is not None:
                cur["telemetria"].append(
                    ("SWAP_USED_MB", sys["swaptotal_mb"] - sys["swapfree_mb"])
                )
        elif section == "top":
            cur["top"] = toks
        elif section == "proto":
            vals = {
                k.lower(): n(k)
                for k in [
                    "IPHdrErr",
                    "IPAddrErr",
                    "IPUnkProto",
                    "IPReasFail",
                    "IPFragFail",
                    "TCPFailedConn",
                    "TCPEstRst",
                    "TCPRetraSeg",
                    "UDPUnkPort",
                    "UDPRcvErr",
                ]
            }
            cur["proto"] = {
                **(cur["proto"] or {}),
                **{k: v for k, v in vals.items() if v is not None},
            }
            for key, metric in [
                ("ipreasfail", "NET_IP_REASM_FAIL"),
                ("tcpretraseg", "NET_TCP_RETRA_SEG"),
            ]:
                if vals[key] is not None:
                    cur["telemetria"].append((metric, vals[key]))
        elif section == "nics":
            nic = {
                k: n(k)
                for k in [
                    "netrr",
                    "netwr",
                    "neteff",
                    "nicerrors",
                    "pktsin",
                    "pktsout",
                    "errsin",
                    "errsout",
                    "indiscarded",
                    "outdiscarded",
                ]
            }
            nic.update(
                name=toks.get("name"),
                type=toks.get("type") or "UNCLASSIFIED",
                latency_ms=n("latency"),
                latency_lt=str(toks.get("latency", "")).startswith("<"),
                mtu=n("mtu"),
                line=line,
                source=str(path),
            )
            cur["nics"].append(nic)
        elif section == "devices":
            dev = {k: n(k) for k in ["ior", "iow", "ios", "qlen"]}
            dev.update(
                name=toks.get("name"),
                type=toks.get("type"),
                wait_ms=n("wait"),
                line=line,
                source=str(path),
            )
            if dev["wait_ms"] is not None and dev["wait_ms"] > 1_000_000:
                issues.append(
                    {
                        "field": "wait",
                        "raw": toks.get("wait"),
                        "quality": "suspect",
                        "reason": "Extreme observed interval mean; cause unvalidated, value retained",
                    }
                )
            dev["quality"] = (
                "suspect"
                if any(i["quality"] == "suspect" for i in issues)
                else "observed"
            )
            cur["devices"].append(dev)
        elif section == "filesystems":
            fs = {
                "mount": toks.get("mount"),
                "fstype": toks.get("type"),
                "line": line,
                "source": str(path),
            }
            for key, dest in [
                ("total", "total_kb"),
                ("used", "used_kb"),
                ("available", "avail_kb"),
            ]:
                fs[dest] = n(key)
            fs["used_pct"] = (
                n("used%" if "used%" in toks else "used")
                if "used%" in toks
                else number(raw.get("used[%]"), issues, "used%")
            )
            fs["ifree_pct"] = n("ifree%" if "ifree%" in toks else "ifree")
            if fs["total_kb"] is None or fs["total_kb"] <= 0:
                fs["quality"] = "capacity_unavailable"
                issues.append(
                    {
                        "field": "total",
                        "raw": toks.get("total"),
                        "quality": "capacity_unavailable",
                    }
                )
                fs["used_pct"] = None
            else:
                fs["quality"] = "observed"
                # Preserve source percentage; reserved blocks can explain discrepancy.
            cur["filesystems"].append(fs)
        elif section == "cpus":
            cur["cpus"].append(
                {"id": toks.get("ID"), "usage": n("usage"), "line": line}
            )
        elif section == "processes":
            name = toks.get("name")
            if name:
                rec = ranks.setdefault(cur["node"], {}).setdefault(
                    name,
                    {
                        "name": name,
                        "pid": None,
                        "n": 0,
                        "max_cpuusage": 0,
                        "max_privmem_kb": 0,
                        "max_shm_kb": 0,
                        "max_fd": 0,
                        "max_threads": 0,
                        "last_t": None,
                    },
                )
                rec["pid"] = n("pid")
                rec["n"] += 1
                frame = cur["process_metrics"].setdefault(name, {})
                for key, dest in [
                    ("cpuusage", "max_cpuusage"),
                    ("privmem", "max_privmem_kb"),
                    ("shm", "max_shm_kb"),
                    ("#fd", "max_fd"),
                    ("#threads", "max_threads"),
                ]:
                    value = n(key)
                    frame[dest] = (
                        max(frame.get(dest) or value or 0, value)
                        if value is not None
                        else frame.get(dest)
                    )
                    if value is not None:
                        rec[dest] = max(rec[dest], value)
                rec["last_t"] = cur["clock"].isoformat() if cur["clock"] else None
        sec["matched"] += 1
        for issue in issues:
            key = issue["quality"]
            diag["quality_counts"][key] = diag["quality_counts"].get(key, 0) + 1

    def finish():
        if cur is None:
            return
        if cur["clock"] is not None and cur["sys"] is not None:
            # Explicit NULL rows prevent downstream SQL lag() from skipping an
            # unavailable observation and differencing across it.
            metrics = dict(cur["telemetria"])
            cur["telemetria"] = [
                (key, metrics.get(key))
                for key in (
                    "CPU_USAGE_PCT",
                    "IO_READ_RATE_KBPS",
                    "IO_WRITE_RATE_KBPS",
                    "IO_OPS_PER_SEC",
                    "SWAP_IN_KBPS",
                    "SWAP_OUT_KBPS",
                    "SWAP_USED_MB",
                    "NET_IP_REASM_FAIL",
                    "NET_TCP_RETRA_SEG",
                )
            ]
            samples.append(cur)
            diag["accepted"] += 1
        else:
            diag["rejected"] += 1
            if len(diag["errors"]) < 40:
                diag["errors"].append(
                    {
                        "line_no": cur["line"],
                        "msg": "Node block rejected: invalid clock or no SYSTEM data",
                    }
                )

    with TimedText(path, diag, encoding="utf-8-sig", errors="replace") as stream:
        csv_buffer = ""
        csv_start = 0
        for lineno, line in enumerate(stream, 1):
            diag["total_lines"] = lineno
            if csv_buffer:
                line = csv_buffer + line
            stripped = line.strip()
            match = NODE.search(stripped)
            if match:
                if pending:
                    emit(section, pending, pending_line)
                finish()
                node, stamp, serial = match.groups()
                dt = clock(stamp)
                cur = {
                    "node": node,
                    "clock": dt,
                    "clock_raw": stamp,
                    "serial": serial,
                    "sys": None,
                    "top": None,
                    "nics": [],
                    "devices": [],
                    "filesystems": [],
                    "cpus": [],
                    "proto": None,
                    "telemetria": [],
                    "records": [],
                    "process_metrics": {},
                    "source": str(path),
                    "line": lineno,
                }
                diag["samples"] += 1
                diag["node_names"].add(node)
                if dt is not None:
                    for key, op in [("first_clock", min), ("last_clock", max)]:
                        prev = diag[key]
                        diag[key] = (
                            dt
                            if prev is None
                            else op(
                                [prev, dt],
                                key=lambda d: (
                                    d.replace(tzinfo=timezone.utc).timestamp()
                                    if d.tzinfo is None
                                    else d.timestamp()
                                ),
                            )
                        )
                section = header = pending = None
                continue
            if not stripped or set(stripped) == {"-"}:
                continue
            candidate = stripped.rstrip(":")
            if stripped.endswith(":") and candidate in SECTIONS:
                if pending:
                    emit(section, pending, pending_line)
                section = SECTIONS[candidate]
                header = pending = None
                if section in UNIMPLEMENTED:
                    diag["omitted_sections"][section] = (
                        "recognized; domain adapter not implemented"
                    )
                continue
            if stripped.endswith(":") and re.fullmatch(r"[A-Z_ ]+:", stripped):
                if pending:
                    emit(section, pending, pending_line)
                diag["omitted_sections"][candidate] = "unknown section; not parsed"
                section = header = pending = None
                continue
            if cur is None or section is None:
                continue
            if stripped.startswith('"') or header is not None:
                diag["formats"].add("csv-sections")
                try:
                    values = next(
                        csv.reader(line.splitlines(keepends=True), strict=True)
                    )
                    record_line = csv_start or lineno
                    csv_buffer = ""
                    csv_start = 0
                    if header is None or (
                        section == "proto" and any("[#]" in v for v in values)
                    ):
                        header = values
                    elif len(values) == len(header):
                        emit(section, dict(zip(header, values)), record_line)
                    else:
                        raise ValueError(
                            f"CSV fields: expected {len(header)}, found {len(values)}"
                        )
                except (csv.Error, ValueError) as exc:
                    if isinstance(exc, csv.Error) and "unexpected end" in str(exc):
                        csv_buffer = line
                        if not csv_start:
                            csv_start = lineno
                        continue
                    if len(diag["errors"]) < 40:
                        diag["errors"].append({"line_no": lineno, "msg": str(exc)})
                continue
            diag["formats"].add("legacy")
            fields = {
                m.group(1): m.group(2).strip("'") for m in TOKEN.finditer(stripped)
            }
            # Legacy SYSTEM/protocol records may span lines; entity records start by name/mount.
            if section in ("nics", "devices") and fields:
                first = stripped.split()[0]
                if ":" not in first:
                    fields["name"] = first
            new_entity = "name" in fields or "mount" in fields
            if pending and new_entity:
                emit(section, pending, pending_line)
                pending = None
            if fields:
                if pending is None:
                    pending, pending_line = {}, lineno
                pending.update(fields)
    if csv_buffer:
        diag["errors"].append(
            {"line_no": csv_start, "msg": "Unterminated quoted CSV record"}
        )
    if pending:
        emit(section, pending, pending_line)
    finish()
    if diag["samples"] and not diag["accepted"]:
        diag["errors"].append(
            {
                "msg": "Node blocks found but zero accepted samples; unsupported or malformed source"
            }
        )
    diag["processing_status"] = (
        "rejected"
        if not diag["accepted"]
        else "partial"
        if diag["rejected"]
        or diag["errors"]
        or diag["omitted_sections"]
        or any(s["unknown_keys"] for s in diag["sections"].values())
        else "processed"
    )
    return samples, diag, ranks
