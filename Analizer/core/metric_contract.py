"""OCLUMON semantics shared by normalization, report help and comparison."""

ORACLE11 = "https://docs.oracle.com/cd/E11882_01/rac.112/e41959/troubleshoot.htm"
ORACLECSV = "https://docs.oracle.com/en/database/oracle/oracle-database/12.2/atnms/oclumon-dumpnodeview.html"

SYSTEM = {
    "cpu_pct": ("cpu / cpuusage", "%", "%", "instantaneous", "identity"),
    "cpuq": ("cpuq / #cpuq", "processes", "processes", "instantaneous", "identity"),
    "memfree_gib": ("physmemfree", "KB", "GiB", "instantaneous", "divide by 1048576"),
    "memavl_gib": (
        "memavl",
        "KB",
        "GiB",
        "instantaneous",
        "divide by 1048576; never inferred",
    ),
    "mcache_gib": (
        "mcache / buffer&cache",
        "KB",
        "GiB",
        "instantaneous",
        "divide by 1048576; no additive cache fields",
    ),
    "swapfree_mb": ("swapfree", "KB", "MiB", "instantaneous", "divide by 1024"),
    "swpin": ("swpin", "KB/s", "KB/s", "rate", "identity"),
    "swpout": ("swpout", "KB/s", "KB/s", "rate", "identity"),
    "ior": ("ior", "KB/s", "KB/s", "rate", "identity"),
    "iow": ("iow", "KB/s", "KB/s", "rate", "identity"),
    "ios": ("ios", "operations/s", "operations/s", "rate", "identity"),
    "netr": (
        "netr / netrr",
        "KB/s",
        "KB/s",
        "rate",
        "source host total; not sum of NICs",
    ),
    "netw": (
        "netw / netwr",
        "KB/s",
        "KB/s",
        "rate",
        "source host total; not sum of NICs",
    ),
    "procs": ("procs / #procs", "processes", "processes", "instantaneous", "identity"),
    "nicerrors_sistema": (
        "nicErrors",
        "errors/s",
        "errors/s",
        "rate",
        "identity; no delta",
    ),
}


def contract(key):
    scope, section = "host", "SYSTEM"
    if key in SYSTEM:
        field, original, unit, kind, transformation = SYSTEM[key]
    elif key.startswith("proto_") or key in ("ip_reasfail", "udp_rcverr"):
        field = key.replace("proto_", "")
        original, unit, kind, transformation = (
            "count",
            "increments",
            "counter_increment",
            "one delta before visual filtering; reset/gap/first/unknown = null",
        )
        section = "PROTOCOL ERRORS / PROTOCOLS"
    elif key.startswith("dev::"):
        field = key.split("::")[-1]
        scope = "device"
        section = "DEVICES / DEVICE"
        original = unit = {
            "ior": "KB/s",
            "iow": "KB/s",
            "ios": "operations/s",
            "qlen": "requests",
            "wait_ms": "ms",
        }.get(field, "source unit")
        kind = (
            "interval_mean"
            if field == "wait_ms"
            else "rate"
            if field in ("ior", "iow", "ios")
            else "instantaneous"
        )
        transformation = (
            "identity; no sum across overlapping disks/partitions/dm; extremes retained"
        )
    elif key.startswith("fs::"):
        field = key.split("::")[-1]
        scope = "mount"
        section = "FILESYSTEMS / FILESYSTEM"
        original, unit = ("%", "%") if field == "used_pct" else ("KB", "MiB")
        kind = "instantaneous"
        transformation = (
            "source used%; capacity <=0 or absent = unavailable; KB /1024 once"
        )
    elif (
        key.startswith("nic::")
        or key.startswith("nic_")
        or key.startswith("interconnect_")
    ):
        scope = "NIC" if key.startswith("nic::") else "NIC type (descriptive aggregate)"
        section = "NICS / NIC"
        field = key.split("::")[-1]
        if "latency" in key:
            original = unit = "ms"
            kind = "interval_mean"
            transformation = "source bound < preserved; not RAC operation latency"
        else:
            original = unit = (
                "KB/s"
                if any(w in key for w in ("kbps", "netrr", "netwr"))
                else "packets/s"
                if any(w in key for w in ("pkts", "discard"))
                else "errors/s"
            )
            kind = "rate"
            transformation = (
                "identity; no delta; no link utilization without known link speed"
            )
    elif key.startswith("proc::"):
        section = "PROCESSES / PROCESS"
        scope = "process name: maximum individual PID observed per interval, not sum"
        field = key.rsplit("::", 1)[-1]
        kind = "interval_mean" if field == "max_cpuusage" else "instantaneous"
        original = unit = (
            "%" if field == "max_cpuusage" else "KB" if "_kb" in field else "count"
        )
        transformation = "maximum among listed PIDs of this name per source interval; original PIDs preserved in DuckDB"
    elif key.startswith("cpu::"):
        field = "usage"
        original = unit = "%"
        kind = "instantaneous"
        transformation = "identity"
        scope = "CPU"
        section = "CPU"
    else:
        field = key
        original = unit = "source unit"
        kind = "instantaneous"
        transformation = "identity"
    return {
        "section": section,
        "field": field,
        "original_unit": original,
        "unit": unit,
        "kind": kind,
        "scope": scope,
        "transformation": transformation,
        "missing": "null; zero remains observed zero; no extension across gaps",
        "aggregation": "sum valid increments / valid duration"
        if kind == "counter_increment"
        else "integrate rate × valid interval; duration-weighted mean"
        if kind == "rate"
        else "sample mean and sample quantiles; no claim of operation percentile"
        if kind == "interval_mean"
        else "sample mean/min/max; coverage explicit",
        "reference": ORACLE11,
        "format_reference": ORACLECSV,
    }


def cadence(times):
    from statistics import median

    diffs = sorted(b - a for a, b in zip(times, times[1:]) if b > a)
    return max(1, median(diffs[: max(1, len(diffs) // 2)])) if diffs else 1


def sum_known(*values):
    return sum(values) if values and all(v is not None for v in values) else None
