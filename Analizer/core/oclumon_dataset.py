"""Observation identity, discontinuities, provenance and nullable derived metrics."""

from datetime import timezone
from core.metric_contract import cadence, sum_known


def epoch(dt):
    if isinstance(dt, str):
        from datetime import datetime

        dt = datetime.fromisoformat(dt)
    return (
        dt.replace(tzinfo=timezone.utc).timestamp()
        if dt.tzinfo is None
        else dt.timestamp()
    )


def zone(sample):
    dt = sample["clock"]
    return dt.strftime("%z") if dt.tzinfo else "unknown"


def identity(sample):
    return sample["node"], epoch(sample["clock"]), zone(sample)


def deduplicate(samples):
    # Retain disjoint entity observations at the same timestamp; deterministic
    # first observation wins conflicting fields, and both raw sources survive.
    merged = {}
    conflicts = []
    duplicates = 0
    for sample in samples:
        key = identity(sample)
        if key not in merged:
            merged[key] = sample
            continue
        target = merged[key]
        duplicates += 1
        for section, entity in [
            ("devices", "name"),
            ("nics", "name"),
            ("filesystems", "mount"),
            ("cpus", "id"),
        ]:
            existing = {r.get(entity): r for r in target[section]}
            for row in sample[section]:
                old = existing.get(row.get(entity))
                if old is None:
                    target[section].append(row)
                    existing[row.get(entity)] = row
                else:
                    for field, value in row.items():
                        if field in ("line", "source"):
                            continue
                        if old.get(field) is None:
                            old[field] = value
                        elif value is not None and value != old[field]:
                            conflicts.append(
                                {
                                    "node": key[0],
                                    "time": sample["clock"].isoformat(),
                                    "section": section,
                                    "entity": row.get(entity),
                                    "field": field,
                                    "resolution": "first observation retained",
                                    "source": sample["source"],
                                }
                            )
        for section in ("sys", "proto"):
            for field, value in (sample.get(section) or {}).items():
                old = (target.get(section) or {}).get(field)
                if old is None:
                    if target.get(section) is None:
                        target[section] = {}
                    target[section][field] = value
                elif value is not None and value != old:
                    conflicts.append(
                        {
                            "node": key[0],
                            "time": sample["clock"].isoformat(),
                            "section": section,
                            "field": field,
                            "resolution": "first observation retained",
                            "source": sample["source"],
                        }
                    )
        target["records"].extend(sample["records"])
    return list(merged.values()), {
        "overlapping_blocks": duplicates,
        "conflicts": conflicts,
    }


def build(samples):
    grouped = {}
    for sample in samples:
        grouped.setdefault(sample["node"], []).append(sample)
    result = {}
    for node, items in grouped.items():
        items.sort(key=lambda s: epoch(s["clock"]))
        step = cadence([epoch(s["clock"]) for s in items])
        rows = []
        previous = None
        segment = 0
        for s in items:
            t = epoch(s["clock"])
            discontinuity = (
                previous is None
                or zone(s) != zone(previous)
                or t - epoch(previous["clock"]) > step * 3
            )
            if discontinuity:
                segment += 1
            delta = {}
            reasons = {}
            for key, value in (s["proto"] or {}).items():
                prior = (previous.get("proto") or {}).get(key) if previous else None
                reason = (
                    "first_or_gap"
                    if discontinuity
                    else "unavailable"
                    if value is None or prior is None
                    else "reset"
                    if value < prior
                    else None
                )
                delta[key] = None if reason else value - prior
                if reason:
                    reasons[key] = reason
            aggregates = {}
            for nic in s["nics"]:
                aggregates.setdefault(nic["type"], []).append(nic)
            by_type = {}
            for kind, nics in aggregates.items():
                out = {
                    key: sum_known(*(n.get(key) for n in nics))
                    for key in [
                        "netrr",
                        "netwr",
                        "nicerrors",
                        "indiscarded",
                        "outdiscarded",
                        "pktsin",
                        "pktsout",
                        "errsin",
                        "errsout",
                    ]
                }
                # For compatibility only. Individual interfaces are also exposed;
                # type totals can include layers and are never cluster utilization.
                eff = [n["neteff"] for n in nics if n["neteff"] is not None]
                lat = [n for n in nics if n["latency_ms"] is not None]
                peak = max(lat, key=lambda n: n["latency_ms"]) if lat else None
                out.update(
                    neteff_avg=sum(eff) / len(eff) if len(eff) == len(nics) else None,
                    latency_ms_max=peak["latency_ms"] if peak else None,
                    latency_ms_max_lt=peak["latency_lt"] if peak else False,
                )
                by_type[kind] = out
            rows.append(
                {
                    "t": s["clock"].isoformat(),
                    "sys": s["sys"],
                    "top": s["top"],
                    "nics_by_type": by_type,
                    "nics": s["nics"],
                    "devices": s["devices"],
                    "filesystems": s["filesystems"],
                    "cpus": s["cpus"],
                    "process_metrics": s.get("process_metrics", {}),
                    "source": s["source"],
                    "line": s["line"],
                    "segment": segment,
                    "zone": zone(s),
                    "proto_raw": s["proto"],
                    "proto_delta": delta,
                    "proto_quality": reasons,
                    "cadence": step,
                }
            )
            previous = s
        result[node] = rows
    return result
