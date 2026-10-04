"""
core/episode_engine.py

Motor de episodios + linea de tiempo narrada -- el "cerebro de senal" que le
faltaba a rac-lab. Hasta este hito, rac-lab volcaba CADA fila cruda (una por
muestra de oclumon, una por linea de Clusterware, un bloque por cada *** de
un trace) directo a la tabla Tabulator del dashboard: miles de filas, cero
agrupacion, cero interpretacion -- el usuario lo describio con precision el
2026-10-01: "hay data en bruto demasiada no hay senales de ningun evento
puntual".

Mientras tanto, la herramienta de campo (`oclumon_analyzer.py`, en la raiz
de `dept300/`) SI resuelve esto bien, y lo viene resolviendo desde antes de
que existiera rac-lab: agrupa eventos discretos en EPISODIOS contiguos (una
rafaga de 131 muestras casi identicas se convierte en 1 tarjeta, no en 131
filas), les agrega una interpretacion tecnica en lenguaje natural desde una
base de conocimiento fija (determinista, sin LLM), y arma una LINEA DE
TIEMPO consolidada cruzando esos episodios con los eventos del alert log.

Este modulo es un PORT deliberado de esa logica ya probada (el usuario la
calificio directamente de "el analizador de ayer construia bien") --
`parse_file`, `build_dataset`, `nic_types`, `detect_anomalias`,
`INTERP_KB`, `build_episodios`, `parse_alert_log`, `build_timeline` y
`build_proc_rankings` son el mismo algoritmo, con las mismas reglas,
umbrales y textos de interpretacion que ya se verificaron contra datos
reales de DEPT300 (incluyendo los archivos CHM de 4+ MB subidos el
2026-10-01) -- no una reescritura desde cero. Se renombraron un par de
identificadores al castellano para mantener consistencia con el resto de
`rac-lab`, pero la logica interna (umbrales, EPISODE_GAP_SECONDS=120,
agrupacion por (nodo, categoria), orden por severidad) es identica.

Deliberadamente NO vive en DuckDB: opera directo sobre los archivos de
oclumon/alert ya clasificados por `core/router.py`, igual que hace
`oclumon_analyzer.py` -- csrc/eventos_forenses sigue siendo la fuente para
AWR/Clusterware/trace/sar y para `ai.engine.calcular_estado_salud()`, pero
la narrativa de "que paso puntualmente" sale de aca, no de un SELECT sobre
filas crudas.

Por pedido explicito del proyecto: ninguna linea/archivo mal formado debe
tumbar el analisis completo.
"""

import re
import logging
from datetime import datetime, timezone
from statistics import median

log = logging.getLogger("rac_forensic_lab.core.episode_engine")

MAX_UNPARSED_SAMPLES = 40
MAX_ERROR_SAMPLES = 40


def _epoch_hora_origen(valor) -> int:
    """Convierte una hora local *sin zona* en un eje estable.

    CHM no declara zona horaria. Se usa UTC como contenedor neutro para que
    02:35 siga siendo 02:35 al abrir el HTML en cualquier equipo; no significa
    que la captura ocurriera realmente en UTC.
    """
    dt = valor if isinstance(valor, datetime) else datetime.fromisoformat(valor)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


def _insertar_huecos(puntos):
    """Inserta un null cuando falta más de tres intervalos de muestreo.

    `connectNulls:false` sólo corta una línea si el dataset contiene el hueco;
    timestamps distantes sin un null se conectan con una diagonal engañosa.
    """
    if len(puntos) < 3:
        return puntos
    diffs = [b["t"] - a["t"] for a, b in zip(puntos, puntos[1:]) if b["t"] > a["t"]]
    if not diffs:
        return puntos
    # La mediana global incluiría el propio hueco en series pequeñas; usar
    # la mitad inferior estima la cadencia real sin dejar que días sin datos
    # eleven artificialmente el umbral.
    rapidos = sorted(diffs)[:max(1, len(diffs) // 2)]
    paso = max(1, int(median(rapidos)))
    umbral = max(60, paso * 3)
    out = [puntos[0]]
    for anterior, actual in zip(puntos, puntos[1:]):
        if actual["t"] - anterior["t"] > umbral:
            out.append({"t": anterior["t"] + paso, "v": None})
        out.append(actual)
    return out


def _a_gib(puntos):
    return [{**p, "v": (p["v"] / 1024.0 if p.get("v") is not None else None)} for p in puntos]


def _detectar_ventanas_captura(nodes):
    """Agrupa timestamps reales en ventanas separadas por huecos de captura."""
    tiempos = sorted({
        _epoch_hora_origen(row["t"])
        for rows in nodes.values() for row in rows if row.get("t")
    })
    if not tiempos:
        return []
    diffs = [b - a for a, b in zip(tiempos, tiempos[1:]) if b > a]
    rapidos = sorted(diffs)[:max(1, len(diffs) // 2)] if diffs else [1]
    paso = max(1, int(median(rapidos)))
    umbral = max(60, paso * 3)
    grupos, actual = [], [tiempos[0]]
    for anterior, t in zip(tiempos, tiempos[1:]):
        if t - anterior > umbral:
            grupos.append(actual)
            actual = []
        actual.append(t)
    grupos.append(actual)
    return [
        {
            "inicio": datetime.fromtimestamp(g[0], timezone.utc).replace(tzinfo=None).isoformat(),
            "fin": datetime.fromtimestamp(g[-1], timezone.utc).replace(tzinfo=None).isoformat(),
            "muestras": len(g),
        }
        for g in grupos
    ]

# ---------------------------------------------------------------------
# Parser de oclumon (CHM) -- tokenizador generico, tolerante a version de
# GI (11g..19c), identico al de oclumon_analyzer.py. Ver docstring del
# modulo para por que NO se asume un orden/conjunto fijo de campos.
# ---------------------------------------------------------------------
TOKEN_RE = re.compile(r"([#A-Za-z][\w#%]*)\s*:\s*('[^']*'|-?\d+\.\d+|-?\d+|\S+)")


def _tokenize(line):
    out = []
    for m in TOKEN_RE.finditer(line):
        key, val = m.group(1), m.group(2)
        if len(val) >= 2 and val.startswith("'") and val.endswith("'"):
            val = val[1:-1]
        out.append((key, val))
    return out


def _as_float(d, key, default=0.0):
    v = d.get(key)
    if v is None or v == "":
        return default
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _as_int(d, key, default=0):
    v = d.get(key)
    if v is None or v == "":
        return default
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


SYS_KNOWN = {
    "cpu", "cpuq", "physmemfree", "physmemtotal", "mcache", "swapfree",
    "swaptotal", "ior", "iow", "ios", "swpin", "swpout", "pgin", "pgout",
    "netr", "netw", "procs", "rtprocs", "#fds", "#sysfdlimit", "#disks",
    "#nics", "nicErrors", "#pcpus", "#vcpus", "chipname", "cpuht",
}
TOP_KNOWN = {"topcpu", "topprivmem", "topshm", "topfd", "topthread"}
NIC_KNOWN = {
    "netrr", "netwr", "neteff", "nicerrors", "pktsin", "pktsout",
    "errsin", "errsout", "indiscarded", "outdiscarded", "inunicast",
    "innonunicast", "type", "latency",
}
PROTO_KNOWN = {
    "IPHdrErr", "IPAddrErr", "IPUnkProto", "IPReasFail", "IPFragFail",
    "TCPFailedConn", "TCPEstRst", "TCPRetraSeg", "UDPUnkPort", "UDPRcvErr",
}
DEV_KNOWN = {"ior", "iow", "ios", "qlen", "wait", "type"}
FS_KNOWN = {"mount", "type", "total", "used", "available", "used%", "ifree%"}
PROC_KNOWN = {
    "name", "pid", "#procfdlimit", "cpuusage", "privmem", "shm", "#fd",
    "#threads", "priority", "nice",
}
STRUCTURED_SECTIONS = {
    "system": SYS_KNOWN, "top": TOP_KNOWN, "nics": NIC_KNOWN, "proto": PROTO_KNOWN,
    "devices": DEV_KNOWN, "filesystems": FS_KNOWN, "processes": PROC_KNOWN,
}
SECTION_HEADERS = {
    "SYSTEM:": "system", "TOP CONSUMERS:": "top", "PROCESSES:": "processes",
    "DEVICES:": "devices", "FILESYSTEMS:": "filesystems", "NICS:": "nics",
    "PROTOCOL ERRORS:": "proto",
}

LATENCY_TOKEN_RE = re.compile(r"[<>]?\s*(-?\d+(?:\.\d+)?)")


def _parse_latency_ms(raw):
    if raw is None or raw == "":
        return None
    m = LATENCY_TOKEN_RE.search(str(raw))
    if not m:
        return None
    try:
        return float(m.group(1))
    except ValueError:
        return None


def _parse_clock(s):
    m = re.match(r"(\d\d)-(\d\d)-(\d\d)\s+(\d\d)\.(\d\d)\.(\d\d)", s.strip())
    if not m:
        return None
    mo, d, y, h, mi, se = map(int, m.groups())
    y += 2000
    try:
        return datetime(y, mo, d, h, mi, se)
    except ValueError:
        return None


def _new_diag(path):
    return {
        "path": path, "total_lines": 0, "samples": 0, "node_names": set(),
        "first_clock": None, "last_clock": None,
        "sections": {
            k: {"lines": 0, "matched": 0, "unmatched": 0, "unknown_keys": set(),
                "unknown_key_samples": {}}
            for k in STRUCTURED_SECTIONS
        },
        "unparsed_samples": [], "errors": [],
    }


def _note_unknown_keys(diag, section, toks, known):
    unk = set(toks.keys()) - known
    if unk:
        sec = diag["sections"][section]
        sec["unknown_keys"].update(unk)
        for k in unk:
            sec["unknown_key_samples"].setdefault(k, toks[k])


def _note_unparsed(diag, lineno, section, line):
    diag["sections"][section]["unmatched"] += 1
    if len(diag["unparsed_samples"]) < MAX_UNPARSED_SAMPLES:
        diag["unparsed_samples"].append({"line_no": lineno, "section": section, "text": line[:200]})


def _new_proc_rank_entry(name):
    return {
        "name": name, "pid": None, "n": 0,
        "max_cpuusage": 0.0, "max_privmem_kb": 0, "max_shm_kb": 0,
        "max_fd": 0, "max_threads": 0, "last_t": None,
    }


def parse_oclumon_file(path):
    """Parsea un dump de `oclumon dumpnodeview -v`. Devuelve
    (samples, diag, proc_rank) -- ver docstring del modulo: port directo
    de oclumon_analyzer.parse_file(), mismo algoritmo, nunca tumba el
    archivo completo por una linea mal formada."""
    samples = []
    cur = None
    section = None
    diag = _new_diag(path)
    proc_rank = {}

    with open(path, errors="replace") as f:
        for lineno, raw in enumerate(f, start=1):
            line = raw.rstrip("\n")
            diag["total_lines"] += 1
            if not line.strip():
                continue
            try:
                toks = dict(_tokenize(line))

                if "Node" in toks and "Clock" in toks:
                    if cur is not None:
                        samples.append(cur)
                    node = toks["Node"]
                    clock = _parse_clock(toks["Clock"])
                    cur = {
                        "node": node, "clock": clock, "serial": toks.get("SerialNo"),
                        "sys": None, "top": None, "nics": [], "proto": None,
                        "devices": [], "filesystems": [],
                    }
                    section = None
                    diag["samples"] += 1
                    diag["node_names"].add(node)
                    if clock is not None:
                        if diag["first_clock"] is None or clock < diag["first_clock"]:
                            diag["first_clock"] = clock
                        if diag["last_clock"] is None or clock > diag["last_clock"]:
                            diag["last_clock"] = clock
                    continue

                if cur is None:
                    continue

                header_hit = False
                for prefix, sec in SECTION_HEADERS.items():
                    if line.startswith(prefix):
                        section = sec
                        header_hit = True
                        break
                if header_hit:
                    continue
                if section is None:
                    continue

                if section == "system":
                    diag["sections"]["system"]["lines"] += 1
                    if toks:
                        cur["sys"] = {
                            "cpu": _as_float(toks, "cpu"),
                            "cpuq": _as_int(toks, "cpuq"),
                            "memfree_mb": _as_int(toks, "physmemfree") // 1024,
                            "memtotal_mb": _as_int(toks, "physmemtotal") // 1024,
                            "mcache_mb": _as_int(toks, "mcache") // 1024,
                            "swapfree_mb": _as_int(toks, "swapfree") // 1024,
                            "swaptotal_mb": _as_int(toks, "swaptotal") // 1024,
                            "swpin": _as_int(toks, "swpin"),
                            "swpout": _as_int(toks, "swpout"),
                            "netr": _as_float(toks, "netr"),
                            "netw": _as_float(toks, "netw"),
                            "procs": _as_int(toks, "procs"),
                            "nicerrors": _as_int(toks, "nicErrors"),
                        }
                        diag["sections"]["system"]["matched"] += 1
                        _note_unknown_keys(diag, "system", toks, SYS_KNOWN)
                    else:
                        _note_unparsed(diag, lineno, "system", line)
                    section = None

                elif section == "top":
                    diag["sections"]["top"]["lines"] += 1
                    if toks:
                        cur["top"] = {
                            "topcpu": toks.get("topcpu", ""), "topprivmem": toks.get("topprivmem", ""),
                            "topshm": toks.get("topshm", ""), "topfd": toks.get("topfd", ""),
                            "topthread": toks.get("topthread", ""),
                        }
                        diag["sections"]["top"]["matched"] += 1
                        _note_unknown_keys(diag, "top", toks, TOP_KNOWN)
                    else:
                        _note_unparsed(diag, lineno, "top", line)
                    section = None

                elif section == "nics":
                    diag["sections"]["nics"]["lines"] += 1
                    if toks:
                        parts = line.strip().split(None, 1)
                        first_tok = parts[0] if parts else ""
                        name = first_tok.split(":", 1)[0] if first_tok else "?"
                        cur["nics"].append({
                            "name": line.strip().split(":", 1)[0].split()[0],
                            "name": name, "netrr": _as_float(toks, "netrr"), "netwr": _as_float(toks, "netwr"),
                            "neteff": _as_float(toks, "neteff", default=None) if "neteff" in toks else None,
                            "nicerrors": _as_int(toks, "nicerrors"),
                            "pktsin": _as_int(toks, "pktsin"), "pktsout": _as_int(toks, "pktsout"),
                            "errsin": _as_int(toks, "errsin"), "errsout": _as_int(toks, "errsout"),
                            "indiscarded": _as_int(toks, "indiscarded"), "outdiscarded": _as_int(toks, "outdiscarded"),
                            "latency_ms": _parse_latency_ms(toks.get("latency")),
                            "latency_lt": str(toks.get("latency", "")).strip().startswith("<"),
                            "type": toks.get("type", "unknown"),
                        })
                        diag["sections"]["nics"]["matched"] += 1
                        _note_unknown_keys(diag, "nics", toks, NIC_KNOWN)
                    else:
                        _note_unparsed(diag, lineno, "nics", line)

                elif section == "proto":
                    diag["sections"]["proto"]["lines"] += 1
                    if toks:
                        cur["proto"] = {
                            "iphdrerr": _as_int(toks, "IPHdrErr"), "ipaddrerr": _as_int(toks, "IPAddrErr"),
                            "ipreasfail": _as_int(toks, "IPReasFail"), "ipfragfail": _as_int(toks, "IPFragFail"),
                            "tcpfailedconn": _as_int(toks, "TCPFailedConn"), "tcpestrst": _as_int(toks, "TCPEstRst"),
                            "tcpretraseg": _as_int(toks, "TCPRetraSeg"), "udpunkport": _as_int(toks, "UDPUnkPort"),
                            "udprcverr": _as_int(toks, "UDPRcvErr"),
                        }
                        diag["sections"]["proto"]["matched"] += 1
                        _note_unknown_keys(diag, "proto", toks, PROTO_KNOWN)
                    else:
                        _note_unparsed(diag, lineno, "proto", line)
                    section = None

                elif section == "devices":
                    diag["sections"]["devices"]["lines"] += 1
                    if toks:
                        parts = line.strip().split(None, 1)
                        first_tok = parts[0] if parts else ""
                        name = first_tok.split(":", 1)[0] if first_tok else "?"
                        cur["devices"].append({
                            "name": name, "ior": _as_float(toks, "ior"), "iow": _as_float(toks, "iow"),
                            "ios": _as_float(toks, "ios"), "qlen": _as_float(toks, "qlen"),
                            "wait_ms": _as_float(toks, "wait"), "type": toks.get("type", ""),
                        })
                        diag["sections"]["devices"]["matched"] += 1
                        _note_unknown_keys(diag, "devices", toks, DEV_KNOWN)
                    else:
                        _note_unparsed(diag, lineno, "devices", line)

                elif section == "filesystems":
                    diag["sections"]["filesystems"]["lines"] += 1
                    if toks and "mount" in toks:
                        cur["filesystems"].append({
                            "mount": toks.get("mount", "?"), "fstype": toks.get("type", ""),
                            "total_kb": _as_int(toks, "total"), "used_kb": _as_int(toks, "used"),
                            "avail_kb": _as_int(toks, "available"),
                            "used_pct": _as_float(toks, "used%", default=None) if "used%" in toks else None,
                            "ifree_pct": _as_float(toks, "ifree%", default=None) if "ifree%" in toks else None,
                        })
                        diag["sections"]["filesystems"]["matched"] += 1
                        _note_unknown_keys(diag, "filesystems", toks, FS_KNOWN)
                    else:
                        _note_unparsed(diag, lineno, "filesystems", line)

                elif section == "processes":
                    diag["sections"]["processes"]["lines"] += 1
                    if toks and "name" in toks and cur is not None:
                        diag["sections"]["processes"]["matched"] += 1
                        _note_unknown_keys(diag, "processes", toks, PROC_KNOWN)
                        node_procs = proc_rank.setdefault(cur["node"], {})
                        name = toks["name"]
                        rec = node_procs.setdefault(name, _new_proc_rank_entry(name))
                        pid = _as_int(toks, "pid", default=0)
                        if pid:
                            rec["pid"] = pid
                        rec["n"] += 1
                        rec["max_cpuusage"] = max(rec["max_cpuusage"], _as_float(toks, "cpuusage"))
                        rec["max_privmem_kb"] = max(rec["max_privmem_kb"], _as_int(toks, "privmem"))
                        rec["max_shm_kb"] = max(rec["max_shm_kb"], _as_int(toks, "shm"))
                        rec["max_fd"] = max(rec["max_fd"], _as_int(toks, "#fd"))
                        rec["max_threads"] = max(rec["max_threads"], _as_int(toks, "#threads"))
                        if cur["clock"] is not None:
                            t_iso = cur["clock"].isoformat()
                            if rec["last_t"] is None or t_iso > rec["last_t"]:
                                rec["last_t"] = t_iso
                    else:
                        _note_unparsed(diag, lineno, "processes", line)
            except Exception as e:
                if len(diag["errors"]) < MAX_ERROR_SAMPLES:
                    diag["errors"].append({"line_no": lineno, "msg": str(e)})
                continue

    if cur is not None:
        samples.append(cur)
    return [s for s in samples if s["clock"] is not None], diag, proc_rank


def merge_proc_rank(dst, src):
    for node, procs in src.items():
        dst_node = dst.setdefault(node, {})
        for name, rec in procs.items():
            if name not in dst_node:
                dst_node[name] = dict(rec)
                continue
            d = dst_node[name]
            d["n"] += rec["n"]
            if rec["pid"]:
                d["pid"] = rec["pid"]
            d["max_cpuusage"] = max(d["max_cpuusage"], rec["max_cpuusage"])
            d["max_privmem_kb"] = max(d["max_privmem_kb"], rec["max_privmem_kb"])
            d["max_shm_kb"] = max(d["max_shm_kb"], rec["max_shm_kb"])
            d["max_fd"] = max(d["max_fd"], rec["max_fd"])
            d["max_threads"] = max(d["max_threads"], rec["max_threads"])
            if rec["last_t"] and (not d["last_t"] or rec["last_t"] > d["last_t"]):
                d["last_t"] = rec["last_t"]
    return dst


def build_proc_rankings(proc_rank, top_n=15):
    out = {}
    for node, procs in proc_rank.items():
        items = list(procs.values())

        def top(key):
            return sorted(items, key=lambda r: r[key], reverse=True)[:top_n]

        out[node] = {
            "by_cpu": top("max_cpuusage"), "by_privmem": top("max_privmem_kb"),
            "by_fd": top("max_fd"), "by_threads": top("max_threads"),
            "total_unique": len(items),
        }
    return out


def nic_types(samples):
    types = set()
    for s in samples:
        for n in s["nics"]:
            types.add(n["type"])
    return sorted(types)


def build_dataset(all_samples):
    """Agrupa por nodo, ordena por tiempo, calcula deltas de PROTOCOL
    ERRORS, agrega NICS por tipo (PRIVATE/PUBLIC). Devuelve {nodo: [filas]}
    -- cada fila es un punto en el tiempo listo para graficar o para
    alimentar detect_anomalias()."""
    by_node = {}
    for s in all_samples:
        by_node.setdefault(s["node"], []).append(s)

    nodes = {}
    for node, samples in by_node.items():
        samples.sort(key=lambda s: s["clock"])
        base_proto = None
        rows = []
        for s in samples:
            row = {"t": s["clock"].isoformat(), "sys": s["sys"], "top": s["top"]}
            by_type = {}
            for n in s["nics"]:
                d = by_type.setdefault(n["type"], {
                    "netrr": 0.0, "netwr": 0.0, "nicerrors": 0,
                    "indiscarded": 0, "outdiscarded": 0,
                    "pktsin": 0, "pktsout": 0, "errsin": 0, "errsout": 0,
                    "_neteff_sum": 0.0, "_neteff_n": 0,
                    "_lat_sum": 0.0, "_lat_n": 0, "_lat_max": 0.0,
                    "_lat_max_lt": False,
                })
                d["netrr"] += n["netrr"]
                d["netwr"] += n["netwr"]
                d["nicerrors"] += n["nicerrors"]
                d["indiscarded"] += n["indiscarded"]
                d["outdiscarded"] += n["outdiscarded"]
                d["pktsin"] += n.get("pktsin", 0)
                d["pktsout"] += n.get("pktsout", 0)
                d["errsin"] += n.get("errsin", 0)
                d["errsout"] += n.get("errsout", 0)
                if n.get("neteff") is not None:
                    d["_neteff_sum"] += n["neteff"]
                    d["_neteff_n"] += 1
                if n.get("latency_ms") is not None:
                    d["_lat_sum"] += n["latency_ms"]
                    d["_lat_n"] += 1
                    if n["latency_ms"] >= d["_lat_max"]:
                        d["_lat_max"] = n["latency_ms"]
                        d["_lat_max_lt"] = n.get("latency_lt", False)

            row_by_type = {}
            for t, d in by_type.items():
                row_by_type[t] = {
                    "netrr": d["netrr"], "netwr": d["netwr"], "nicerrors": d["nicerrors"],
                    "indiscarded": d["indiscarded"], "outdiscarded": d["outdiscarded"],
                    "pktsin": d["pktsin"], "pktsout": d["pktsout"],
                    "errsin": d["errsin"], "errsout": d["errsout"],
                    "neteff_avg": (d["_neteff_sum"] / d["_neteff_n"]) if d["_neteff_n"] else None,
                    "latency_ms_avg": (d["_lat_sum"] / d["_lat_n"]) if d["_lat_n"] else None,
                    "latency_ms_max": d["_lat_max"] if d["_lat_n"] else None,
                    "latency_ms_max_lt": d["_lat_max_lt"] if d["_lat_n"] else False,
                }
            row["nics_by_type"] = row_by_type
            row["devices"] = s.get("devices", [])
            row["filesystems"] = s.get("filesystems", [])

            if s["proto"]:
                if base_proto is None:
                    base_proto = s["proto"]
                row["proto_delta"] = {k: s["proto"][k] - base_proto[k] for k in s["proto"]}
                row["proto_raw"] = s["proto"]
            else:
                row["proto_delta"] = None
                row["proto_raw"] = None
            rows.append(row)
        nodes[node] = rows
    return nodes


# ---------------------------------------------------------------------
# Deteccion de anomalias + interpretacion -- deliberadamente SIN LLM,
# igual disciplina offline que el resto del proyecto. INTERP_KB es la
# misma base de conocimiento fija de oclumon_analyzer.py.
# ---------------------------------------------------------------------
INTERP_KB = {
    "swap": {
        "label": "Actividad de swap",
        "explica": (
            "El sistema operativo empezo a paginar memoria a disco (swap in/out). En un "
            "nodo RAC esto es especialmente delicado: los procesos de Cache Fusion (LMSn) "
            "y el propio Clusterware compiten por CPU y memoria, y una pausa causada por "
            "swapping puede retrasar la respuesta a heartbeats del interconnect el tiempo "
            "suficiente para que Cluster Synchronization Service (CSS) considere el nodo "
            "no responsivo y lo expulse del cluster (node eviction), aunque la red en si "
            "este sana."
        ),
    },
    "cpu_queue": {
        "label": "Cola de CPU elevada",
        "explica": (
            "La cola de ejecucion de CPU (cpuq) mide procesos esperando CPU disponible. "
            "Cuando crece de forma sostenida, los procesos criticos de Clusterware (LMON, "
            "LMD0, LMSn, ocssd.bin) pueden no recibir tiempo de CPU a tiempo para "
            "responder a los heartbeats del interconnect, lo que CSS puede interpretar "
            "como falta de respuesta del nodo."
        ),
    },
    "nic_errors_hw": {
        "label": "Errores de tarjeta de red",
        "explica": (
            "Errores reportados directamente por el driver/hardware de la tarjeta de red "
            "-- a diferencia de los contadores de protocolo IP, estos son errores de capa "
            "de enlace, y suelen apuntar a un problema fisico o de driver: cable, puerto "
            "de switch, negociacion de velocidad/duplex, o firmware de NIC."
        ),
    },
    "interconnect_burst": {
        "label": "Rafaga de trafico en el interconnect",
        "explica": (
            "El trafico en la interfaz privada (interconnect) subio abruptamente por "
            "encima de su patron reciente. En RAC esto suele corresponder a trafico de "
            "Cache Fusion (transferencia de bloques entre instancias via GCS/GES) o a una "
            "reconfiguracion de cluster en curso. Una rafaga grande es la precondicion "
            "tipica para saturar los buffers de reensamblado de paquetes fragmentados "
            "cuando la MTU configurada es insuficiente para el tamano de los mensajes de "
            "Cache Fusion."
        ),
    },
    "nic_discards": {
        "label": "Paquetes descartados en NIC privada",
        "explica": (
            "La propia tarjeta de red descarto paquetes entrantes o salientes, "
            "normalmente porque su buffer de recepcion/transmision se lleno antes de que "
            "el kernel pudiera vaciarlo. Bajo rafagas de trafico de interconnect esto es "
            "una causa directa de perdida de paquetes de Cache Fusion, que Oracle traduce "
            "en 'gc lost blocks' a nivel de base de datos."
        ),
    },
    "nic_link_errors": {
        "label": "Errores de capa NIC (errsin/errsout)",
        "explica": (
            "Contadores de error reportados por la propia tarjeta/driver de red, "
            "separados de nicErrors (que es un contador agregado a nivel de "
            "sistema). Un incremento aqui apunta a la interfaz fisica en si "
            "-- cable, puerto, negociacion -- mas que a saturacion de buffers "
            "del kernel."
        ),
    },
    "nic_latency": {
        "label": "Latencia elevada en NIC privada",
        "explica": (
            "Latencia reportada por oclumon para la interfaz privada. En el "
            "interconnect de RAC esta es la metrica mas cercana a lo que "
            "Oracle mide como tiempo de respuesta IPC: una latencia elevada "
            "sostenida es consistente con mensajes que no llegan a tiempo y "
            "terminan en 'IPC Send timeout' en el alert log, el mismo patron "
            "que suele preceder a una eviction de nodo."
        ),
    },
    "ip_reasfail": {
        "label": "Fallos de reensamblado IP (IPReasFail)",
        "explica": (
            "El kernel de Linux no logro reensamblar un datagrama IP fragmentado dentro "
            "del tiempo/espacio disponible en su buffer de reensamblado (controlado por "
            "net.ipv4.ipfrag_high_thresh / ipfrag_low_thresh y el timeout ipfrag_time). "
            "Esto ocurre tipicamente cuando el tamano de los mensajes de Cache Fusion "
            "(multiplos del db_block_size) excede la MTU de la interfaz privada y el "
            "volumen de fragmentos satura el buffer antes de completar el reensamblado. "
            "El paquete se descarta completo, el mensaje IPC nunca llega, y Oracle lo "
            "registra como 'IPC Send timeout' en el alert log -- una causa raiz clasica "
            "detras de evictions de nodo que a simple vista parecen solo 'un problema de "
            "red'."
        ),
    },
    "device_state": {
        "label": "Dispositivo en estado anomalo",
        "explica": (
            "oclumon reporta el dispositivo con un rol/estado distinto de ONLINE "
            "(por ejemplo un voting disk o disco de OCR/ASM fuera de linea). Un "
            "voting disk inaccesible reduce el quorum disponible para CSS; si la "
            "mayoria de voting disks se vuelve inaccesible, CSS puede forzar el "
            "reinicio o la expulsion del nodo para proteger la integridad del "
            "cluster, incluso si la causa real fue de almacenamiento y no de red."
        ),
    },
    "device_wait": {
        "label": "Espera de I/O elevada",
        "explica": (
            "El tiempo de espera reportado por oclumon para este dispositivo "
            "subio de forma notable. En OCFS2/ASM sobre almacenamiento "
            "compartido, latencia de I/O sostenida puede retrasar escrituras de "
            "voting disk/OCR o del propio redo/control file, y de forma indirecta "
            "hacer que procesos criticos de Clusterware tarden en responder a "
            "heartbeats -- el mismo patron de fondo que una eviction por CPU o "
            "swap, pero originado en el subsistema de disco."
        ),
    },
    "fs_full": {
        "label": "Filesystem cerca de su capacidad",
        "explica": (
            "El punto de montaje vigilado por oclumon (tipicamente GRID_HOME/"
            "ORACLE_BASE) alcanzo un porcentaje de uso critico. Un GRID_HOME sin "
            "espacio puede impedir que Clusterware escriba logs de diagnostico, "
            "haga rotacion de trace files, o incluso bloquear operaciones de "
            "CRS/OPatch -- un riesgo operativo directo, no solo de capacidad."
        ),
    },
    "udp_rcverr": {
        "label": "Errores de recepcion UDP (UDPRcvErr)",
        "explica": (
            "El kernel recibio un datagrama UDP que no pudo entregar a ninguna aplicacion "
            "escuchando en ese puerto, o el buffer de recepcion del socket estaba lleno. "
            "Como el interconnect de Cache Fusion usa UDP, incrementos sostenidos de este "
            "contador junto con IPReasFail refuerzan la hipotesis de saturacion de "
            "red/buffers en el interconnect, no un problema aislado de una sola capa."
        ),
    },
}

EPISODE_GAP_SECONDS = 120
SEV_RANK = {"info": 0, "warning": 1, "critical": 2}


def _fmt_hms(iso_t):
    return datetime.fromisoformat(iso_t).strftime("%H:%M:%S")


def _narrative_sentence(ep):
    node = ep["node"]
    n = ep["n_samples"]
    when = _fmt_hms(ep["start"]) if ep["start"] == ep["end"] else f"{_fmt_hms(ep['start'])}-{_fmt_hms(ep['end'])}"
    span = f" ({ep['duration_s']}s, {n} muestra{'s' if n != 1 else ''})" if n > 1 else ""
    cat = ep["cat"]
    if cat in ("ip_reasfail", "udp_rcverr", "nic_discards", "nic_errors_hw", "nic_link_errors"):
        return (f"En {node}, entre {when}{span}, se acumularon +{int(ep['total_value'])} "
                f"(pico de +{int(ep['peak_value'])} en una sola muestra).")
    if cat == "interconnect_burst":
        return f"En {node}, entre {when}{span}, el trafico del interconnect llego a un pico de {ep['peak_value']:.0f} KB/s."
    if cat == "nic_latency":
        return f"En {node}, entre {when}{span}, la latencia de NIC privada llego a un pico de {ep['peak_value']:.1f} ms."
    if cat == "cpu_queue":
        return f"En {node}, entre {when}{span}, la cola de CPU alcanzo un pico de {int(ep['peak_value'])}."
    if cat == "swap":
        return f"En {node}, entre {when}{span}, el sistema estuvo paginando a swap activamente."
    if cat == "fs_full":
        return f"En {node}, entre {when}{span}, el filesystem llego a un pico de {ep['peak_value']:.0f}% de uso."
    if cat == "device_wait":
        return f"En {node}, entre {when}{span}, la espera de I/O llego a un pico de {ep['peak_value']:.0f} ms."
    if cat == "device_state":
        return f"En {node}, entre {when}{span}, se reporto un dispositivo en estado anomalo ({n} muestra{'s' if n != 1 else ''})."
    return f"En {node}, entre {when}{span}, se detecto esta condicion."


def detect_anomalias(nodes):
    """Reglas simples de deteccion, pensadas para saltar a la vista, no
    para sustituir el analisis fino. Cada regla produce eventos discretos
    para que build_episodios() los agrupe y agregue despues."""
    events = []
    for node, rows in nodes.items():
        prev_proto = None
        netrr_hist = []
        for row in rows:
            t = row["t"]
            sys_ = row["sys"]
            if sys_:
                if sys_["swpin"] > 0 or sys_["swpout"] > 0:
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "swap",
                                    "value": sys_["swpin"] + sys_["swpout"],
                                    "msg": f"Swap activo (swpin={sys_['swpin']}, swpout={sys_['swpout']})"})
                if sys_["cpuq"] >= 6:
                    events.append({"t": t, "node": node, "sev": "warning", "cat": "cpu_queue",
                                    "value": sys_["cpuq"],
                                    "msg": f"Cola de CPU alta (cpuq={sys_['cpuq']})"})
                if sys_["nicerrors"] > 0:
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "nic_errors_hw",
                                    "value": sys_["nicerrors"],
                                    "msg": f"nicErrors={sys_['nicerrors']} a nivel de tarjeta"})
            priv = row["nics_by_type"].get("PRIVATE")
            if priv:
                total = priv["netrr"] + priv["netwr"]
                netrr_hist.append(total)
                if len(netrr_hist) > 6:
                    window = netrr_hist[-7:-1]
                    med = sorted(window)[len(window) // 2] if window else 0
                    if med > 5 and total > med * 4:
                        events.append({"t": t, "node": node, "sev": "info", "cat": "interconnect_burst",
                                        "value": total,
                                        "msg": f"Rafaga de trafico interconnect privado ({total:.0f} KB/s, "
                                               f">4x la mediana reciente de {med:.0f})"})
                if priv["indiscarded"] > 0 or priv["outdiscarded"] > 0:
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "nic_discards",
                                    "value": priv["indiscarded"] + priv["outdiscarded"],
                                    "msg": f"Paquetes descartados en NIC privada (in={priv['indiscarded']}, "
                                           f"out={priv['outdiscarded']})"})
                if priv["errsin"] > 0 or priv["errsout"] > 0:
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "nic_link_errors",
                                    "value": priv["errsin"] + priv["errsout"],
                                    "msg": f"Errores de capa NIC en interfaz privada (errsin={priv['errsin']}, "
                                           f"errsout={priv['errsout']})"})
                if priv.get("latency_ms_max") is not None and priv["latency_ms_max"] >= 5:
                    events.append({"t": t, "node": node, "sev": "warning", "cat": "nic_latency",
                                    "value": priv["latency_ms_max"],
                                    "msg": f"Latencia elevada en NIC privada ({priv['latency_ms_max']:.1f} ms)"})
            if row["proto_delta"] and prev_proto:
                d_reas = row["proto_delta"]["ipreasfail"] - prev_proto["ipreasfail"]
                d_udp = row["proto_delta"]["udprcverr"] - prev_proto["udprcverr"]
                if d_reas > 0:
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "ip_reasfail",
                                    "value": d_reas,
                                    "msg": f"IPReasFail +{d_reas} (fallo de reensamblado IP en el kernel)"})
                if d_udp > 0:
                    events.append({"t": t, "node": node, "sev": "warning", "cat": "udp_rcverr",
                                    "value": d_udp, "msg": f"UDPRcvErr +{d_udp}"})
            if row["proto_delta"]:
                prev_proto = row["proto_delta"]

            for dev in row.get("devices", []):
                dtype = (dev.get("type") or "").upper()
                if dtype and "ONLINE" not in dtype and dtype not in ("SYS", "SWAP"):
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "device_state",
                                    "value": 1,
                                    "msg": f"Dispositivo {dev['name']} reporta estado anomalo: {dev['type']}"})
                if dev.get("wait_ms", 0) >= 20:
                    events.append({"t": t, "node": node, "sev": "warning", "cat": "device_wait",
                                    "value": dev["wait_ms"],
                                    "msg": f"Espera de I/O elevada en {dev['name']} ({dev['wait_ms']:.0f} ms)"})

            for fs in row.get("filesystems", []):
                pct = fs.get("used_pct")
                if pct is None:
                    continue
                if pct >= 95:
                    events.append({"t": t, "node": node, "sev": "critical", "cat": "fs_full",
                                    "value": pct, "msg": f"Filesystem {fs['mount']} al {pct:.0f}% de uso"})
                elif pct >= 90:
                    events.append({"t": t, "node": node, "sev": "warning", "cat": "fs_full",
                                    "value": pct, "msg": f"Filesystem {fs['mount']} al {pct:.0f}% de uso"})
    events.sort(key=lambda e: e["t"])
    return events


def build_episodios(events, gap_seconds=EPISODE_GAP_SECONDS):
    """Agrupa los eventos discretos (uno por muestra) en episodios
    contiguos por (nodo, categoria) y les agrega interpretacion +
    narrativa con los numeros reales agregados."""
    by_key = {}
    for e in events:
        by_key.setdefault((e["node"], e["cat"]), []).append(e)

    episodes = []
    for (node, cat), evs in by_key.items():
        evs.sort(key=lambda e: e["t"])
        cur = None
        last_t = None
        for e in evs:
            t = datetime.fromisoformat(e["t"])
            if cur is None or (t - last_t).total_seconds() > gap_seconds:
                if cur is not None:
                    episodes.append(cur)
                cur = {
                    "node": node, "cat": cat, "sev": e["sev"],
                    "start": e["t"], "end": e["t"],
                    "n_samples": 0, "peak_value": 0.0, "total_value": 0.0,
                    "sample_msgs": [],
                }
            v = e.get("value", 0) or 0
            cur["end"] = e["t"]
            cur["n_samples"] += 1
            cur["peak_value"] = max(cur["peak_value"], v)
            cur["total_value"] += v
            if SEV_RANK.get(e["sev"], 0) > SEV_RANK.get(cur["sev"], 0):
                cur["sev"] = e["sev"]
            if len(cur["sample_msgs"]) < 5:
                cur["sample_msgs"].append(e["msg"])
            last_t = t
        if cur is not None:
            episodes.append(cur)

    for ep in episodes:
        start = datetime.fromisoformat(ep["start"])
        end = datetime.fromisoformat(ep["end"])
        ep["duration_s"] = max(0, int((end - start).total_seconds()))
        kb = INTERP_KB.get(ep["cat"], {"label": ep["cat"], "explica": ""})
        ep["label"] = kb["label"]
        ep["interpretacion"] = kb["explica"]
        ep["narrativa"] = _narrative_sentence(ep)

    episodes.sort(key=lambda e: (-SEV_RANK.get(e["sev"], 0), e["start"]))
    return episodes


def build_timeline(episodios):
    """Linea de tiempo consolidada: episodios de oclumon (OS/CHM),
    ordenados por hora. (Antes tambien mezclaba eventos de alert log --
    ese origen se retiro del alcance del pipeline; ver Hito de
    simplificacion a oclumon+sar+awr.)"""
    items = []
    for ep in episodios:
        items.append({
            "t": ep["start"], "node": ep["node"], "sev": ep["sev"], "source": "oclumon",
            "label": ep["label"], "msg": ep["narrativa"], "interpretacion": ep.get("interpretacion", ""),
        })
    items.sort(key=lambda x: x["t"])
    return items


def serialize_diag(diag):
    sections = {}
    for sec, d in diag["sections"].items():
        sections[sec] = {
            "lines": d["lines"], "matched": d["matched"], "unmatched": d["unmatched"],
            "unknown_keys": sorted(d["unknown_keys"]),
            "unknown_key_samples": d.get("unknown_key_samples", {}),
        }
    return {
        "path": diag["path"], "total_lines": diag["total_lines"], "samples": diag["samples"],
        "node_names": sorted(diag["node_names"]),
        "first_clock": diag["first_clock"].isoformat() if diag["first_clock"] else None,
        "last_clock": diag["last_clock"].isoformat() if diag["last_clock"] else None,
        "sections": sections, "unparsed_samples": diag["unparsed_samples"], "errors": diag["errors"],
    }


def _series_puntos_nodo(rows, campo_sys=None, campo_nic=None, tipo_nic="PRIVATE"):
    """[(epoch_seg, valor), ...] para graficar -- campo_sys lee de
    row['sys'][campo_sys], campo_nic lee de
    row['nics_by_type'][tipo_nic][campo_nic]. Salta puntos sin dato (un
    hueco en el grafico es mas honesto que inventar un cero)."""
    out = []
    for row in rows:
        try:
            t = _epoch_hora_origen(row["t"])
        except Exception:
            continue
        v = None
        if campo_sys is not None and row.get("sys"):
            v = row["sys"].get(campo_sys)
        elif campo_nic is not None:
            nic = (row.get("nics_by_type") or {}).get(tipo_nic)
            if nic:
                v = nic.get(campo_nic)
        if v is None:
            continue
        punto = {"t": t, "v": v}
        if campo_nic == "latency_ms_max" and nic.get("latency_ms_max_lt"):
            punto["lt"] = True
        out.append(punto)
    return out


# Los 9 contadores de PROTOCOL ERRORS que oclumon expone (ver PROTO_KNOWN
# arriba) -- antes solo ipreasfail/udprcverr llegaban a series_por_nodo
# (los 2 que un episodio de interconnect podia disparar); el resto se
# calculaba para deteccion y se descartaba. Pedido explicito del usuario
# (2026-10-02): "todo lo que podamos explotar de la data que se tenga".
PROTO_COUNTERS = [
    "iphdrerr", "ipaddrerr", "ipreasfail", "ipfragfail", "tcpfailedconn",
    "tcpestrst", "tcpretraseg", "udpunkport", "udprcverr",
]


def _series_proto_delta_nodo(rows):
    """{contador: [{"t":..,"v":..}, ...]} para los 9 contadores de
    PROTOCOL ERRORS -- delta POR MUESTRA (nunca cumulativo desde el
    arranque), mismo criterio que ya usaba ip_reasfail/udp_rcverr: cada
    punto es cuantos errores NUEVOS aparecieron desde la muestra
    anterior, nunca negativo (un reinicio de contador no se muestra como
    -N)."""
    out = {nombre: [] for nombre in PROTO_COUNTERS}
    prev = None
    prev_t = None
    for row in rows:
        try:
            t = _epoch_hora_origen(row["t"])
        except Exception:
            continue
        pd = row.get("proto_delta")
        if prev_t is not None and t - prev_t > 60:
            prev = None
        if pd and prev:
            for nombre in PROTO_COUNTERS:
                delta = pd[nombre] - prev[nombre]
                # Un contador menor indica reinicio; esa primera muestra no
                # representa errores nuevos y no debe convertirse en cero.
                if delta >= 0:
                    out[nombre].append({"t": t, "v": delta})
        if pd:
            prev = pd
            prev_t = t
    return out


def _series_nic_tipo(rows, tipo, metrica):
    """Serie de una metrica agregada de NICS para un TIPO (PRIVATE/PUBLIC/
    etc.) puntual -- generaliza el calculo que antes solo corria para
    PRIVATE (ver nota de alcance en analizar_caso). 'kbps' usa neteff_avg
    si oclumon lo trae, o netrr+netwr como respaldo (verificado contra
    chm_nodo2.txt: neteff == netrr+netwr siempre)."""
    out = []
    for row in rows:
        try:
            t = _epoch_hora_origen(row["t"])
        except Exception:
            continue
        nic = (row.get("nics_by_type") or {}).get(tipo)
        if not nic:
            continue
        v = None
        if metrica == "kbps":
            eff = nic.get("neteff_avg")
            v = eff if eff is not None else (nic["netrr"] + nic["netwr"])
        elif metrica == "latency_ms":
            v = nic.get("latency_ms_max")
        elif metrica == "discards":
            v = nic["indiscarded"] + nic["outdiscarded"]
        elif metrica == "link_errors":
            v = nic["errsin"] + nic["errsout"]
        elif metrica == "pktsin":
            v = nic.get("pktsin")
        elif metrica == "pktsout":
            v = nic.get("pktsout")
        elif metrica == "nicerrors":
            v = nic.get("nicerrors")
        if v is None:
            continue
        punto = {"t": t, "v": v}
        if metrica == "latency_ms" and nic.get("latency_ms_max_lt"):
            punto["lt"] = True
        out.append(punto)
    return out


def _series_dispositivo_nodo(rows, device_name, campo):
    """Serie de un campo (ior/iow/ios/qlen/wait_ms) de UN device puntual
    (por nombre) para un nodo -- un device puede no existir en todas las
    muestras de un nodo (o en todos los nodos, si el storage no es
    identico), por eso se busca por nombre en cada fila en vez de asumir
    posicion fija en la lista."""
    out = []
    for row in rows:
        try:
            t = _epoch_hora_origen(row["t"])
        except Exception:
            continue
        v = None
        for d in (row.get("devices") or []):
            if d.get("name") == device_name:
                v = d.get(campo)
                break
        if v is None:
            continue
        out.append({"t": t, "v": v})
    return out


def _series_filesystem_nodo(rows, mount, campo):
    """Serie de un campo de UN filesystem puntual (por punto de montaje)
    para un nodo. campo admite 'avail_mb'/'total_mb' (conversion desde
    los *_kb crudos que parsea oclumon, mas legibles en un grafico) ademas
    de los campos crudos (used_pct, etc.)."""
    out = []
    for row in rows:
        try:
            t = _epoch_hora_origen(row["t"])
        except Exception:
            continue
        v = None
        for f in (row.get("filesystems") or []):
            if f.get("mount") == mount:
                if campo == "avail_mb":
                    raw = f.get("avail_kb")
                    v = (raw / 1024.0) if raw is not None else None
                elif campo == "total_mb":
                    raw = f.get("total_kb")
                    v = (raw / 1024.0) if raw is not None else None
                else:
                    v = f.get(campo)
                break
        if v is None:
            continue
        out.append({"t": t, "v": v})
    return out


def analizar_caso(oclumon_paths, log_cb=lambda s: None):
    """Orquestacion de punta a punta de este motor: parsea TODOS los
    archivos de oclumon de un caso, detecta anomalias, arma episodios +
    linea de tiempo + ranking de procesos + series de graficos. Nunca
    lanza -- un archivo individual mal formado queda registrado en su
    propio diagnostico, nunca tumba el resto del caso (mismo contrato que
    el resto de rac-lab).

    Nota de alcance (Hito de simplificacion, 2026-10): este motor ya NO
    consume alert log/Clusterware/trace -- el pipeline quedo acotado a
    oclumon+sar+awr por decision explicita del usuario. 'episodios' sigue
    siendo un mapa INTERNO (nunca se grafica tal cual): cada episodio
    debe graficarse con la metrica especifica que lo disparo, por eso
    series_por_nodo expone ademas las series de respaldo para
    interconnect (ip_reasfail/udp_rcverr, descartes/errores de NIC) y no
    solo latencia/trafico generico."""
    all_samples = []
    diagnostics = []
    all_proc_rank = {}

    for path in oclumon_paths:
        try:
            samples, diag, prank = parse_oclumon_file(path)
            all_samples.extend(samples)
            diagnostics.append(serialize_diag(diag))
            merge_proc_rank(all_proc_rank, prank)
            log_cb(f"[episodios] {path}: {diag['samples']} muestra(s) oclumon parseadas")
        except Exception as e:
            log_cb(f"[episodios] ERROR parseando {path}: {e}")

    nodes = build_dataset(all_samples) if all_samples else {}
    ventanas_captura = _detectar_ventanas_captura(nodes) if nodes else []
    events = detect_anomalias(nodes) if nodes else []
    episodios = build_episodios(events) if events else []
    proc_rankings = build_proc_rankings(all_proc_rank) if all_proc_rank else {}

    timeline = build_timeline(episodios)

    tipos_nic = nic_types(all_samples)
    nic_names_by_type = {
        tipo: sorted({
            n.get("name") for muestra in all_samples for n in muestra.get("nics", [])
            if n.get("type") == tipo and n.get("name")
        })
        for tipo in tipos_nic
    }

    # Union global de nombres de device/punto de montaje vistos en
    # CUALQUIER nodo -- alimenta el selector del panel "Dispositivos"/
    # "Filesystems" del dashboard (rediseno OCLUMON 2026-10-02): el
    # dashboard es "meramente grafico" por pedido explicito del usuario,
    # asi que estas listas solo existen para que el template arme un
    # <select> con los nombres reales, nunca inventados.
    #
    # Limpieza 2026-10-02 (audit externo pegado por el usuario, punto A.3
    # "selector ciego de dispositivos"): un caso real de storage ASM/
    # multipath puede traer decenas de devices (dept300 trajo 74), la
    # mayoria paths en standby o LUNs sin I/O en la ventana analizada --
    # listarlos TODOS sin criterio es, en palabras del audit, "inmanejable
    # con 40 LUNs ASM". Se filtra device_names a los que tuvieron AL MENOS
    # una muestra con actividad real (ior/iow/ios/wait_ms > 0) y se ordena
    # por esa actividad maxima (el mas activo queda primero, que es ademas
    # el que el selector muestra por defecto). device_names_vistos_total
    # guarda el conteo SIN filtrar, solo para que el template distinga "no
    # habia devices" de "habia devices pero ninguno con actividad" en su
    # estado vacio -- detect_anomalias() sigue recorriendo los devices
    # crudos de cada fila sin este filtro, asi que un device idle que
    # cambia de estado (device_state) sigue generando su evento igual.
    actividad_device = {}
    for rows in nodes.values():
        for row in rows:
            for d in (row.get("devices") or []):
                nombre = d.get("name")
                if not nombre:
                    continue
                pico = max(
                    abs(d.get("ior") or 0), abs(d.get("iow") or 0),
                    abs(d.get("ios") or 0), abs(d.get("wait_ms") or 0),
                )
                if pico > actividad_device.get(nombre, 0.0):
                    actividad_device[nombre] = pico
    device_names_vistos_total = len(actividad_device)
    device_names = sorted(
        (nombre for nombre, pico in actividad_device.items() if pico > 0),
        key=lambda n: (-actividad_device[n], n),
    )
    filesystem_mounts = sorted({
        f.get("mount") for rows in nodes.values() for row in rows
        for f in (row.get("filesystems") or []) if f.get("mount")
    })

    # Series listas para graficar por nodo: CPU, memoria libre, swap libre,
    # trafico/latencia de la interfaz PRIVATE (la que importa para
    # interconnect), mas las series "de respaldo" que un episodio de
    # interconnect puede necesitar graficar como su metrica real disparadora
    # (ip_reasfail/udp_rcverr, descartes y errores de capa NIC) -- antes se
    # calculaban solo para deteccion y se descartaban, ahora quedan
    # expuestas para que el dashboard grafique la causa real, no un par
    # generico de paneles fijos.
    series_por_nodo = {}
    for node, rows in nodes.items():
        series_por_nodo[node] = {
            "cpu_pct": _series_puntos_nodo(rows, campo_sys="cpu"),
            "memfree_gib": _a_gib(_series_puntos_nodo(rows, campo_sys="memfree_mb")),
            "mcache_gib": _a_gib(_series_puntos_nodo(rows, campo_sys="mcache_mb")),
            "swapfree_mb": _series_puntos_nodo(rows, campo_sys="swapfree_mb"),
            "cpuq": _series_puntos_nodo(rows, campo_sys="cpuq"),
            "interconnect_latency_ms": _series_puntos_nodo(rows, campo_nic="latency_ms_max", tipo_nic="PRIVATE"),
        }

        kbps, discards, link_errors = [], [], []
        ip_reasfail, udp_rcverr = [], []
        prev_proto = None
        prev_proto_t = None
        for row in rows:
            try:
                t = _epoch_hora_origen(row["t"])
            except Exception:
                continue
            priv = (row.get("nics_by_type") or {}).get("PRIVATE")
            if priv:
                # neteff ya viene calculado por oclumon (netrr+netwr); se
                # usa el promedio agregado del propio oclumon en vez de
                # volver a sumar netrr+netwr a mano (verificado contra
                # chm_nodo2.txt: neteff == netrr+netwr siempre).
                eff = priv.get("neteff_avg")
                kbps.append({"t": t, "v": eff if eff is not None else (priv["netrr"] + priv["netwr"])})
                discards.append({"t": t, "v": priv["indiscarded"] + priv["outdiscarded"]})
                link_errors.append({"t": t, "v": priv["errsin"] + priv["errsout"]})
            pd = row.get("proto_delta")
            if prev_proto_t is not None and t - prev_proto_t > 60:
                prev_proto = None
            if pd and prev_proto:
                ip_delta = pd["ipreasfail"] - prev_proto["ipreasfail"]
                udp_delta = pd["udprcverr"] - prev_proto["udprcverr"]
                if ip_delta >= 0:
                    ip_reasfail.append({"t": t, "v": ip_delta})
                if udp_delta >= 0:
                    udp_rcverr.append({"t": t, "v": udp_delta})
            if pd:
                prev_proto = pd
                prev_proto_t = t

        series_por_nodo[node]["interconnect_kbps"] = kbps
        series_por_nodo[node]["interconnect_nic_discards"] = discards
        series_por_nodo[node]["interconnect_nic_link_errors"] = link_errors
        series_por_nodo[node]["ip_reasfail"] = ip_reasfail
        series_por_nodo[node]["udp_rcverr"] = udp_rcverr

        # --- Rediseno OCLUMON 2026-10-02: "todo lo que podamos explotar
        # de la data que se tenga" (pedido explicito del usuario) -- lo
        # de arriba queda INTACTO (lo sigue usando el motor de episodios/
        # catalogo, aunque la UI narrativa que lo mostraba se retiro) y
        # esto se agrega aparte, series NUEVAS con nombre propio, para el
        # panel puramente grafico organizado por fuente (OCLUMON/AWR/SAR).

        # Sistema -- lo que ya se exponia (cpu_pct/cpuq/memfree_mb/
        # swapfree_mb) mas el resto de SYS_KNOWN que oclumon ya parsea y
        # que antes se descartaba despues de detect_anomalias().
        series_por_nodo[node]["memtotal_mb"] = _series_puntos_nodo(rows, campo_sys="memtotal_mb")
        series_por_nodo[node]["swaptotal_mb"] = _series_puntos_nodo(rows, campo_sys="swaptotal_mb")
        series_por_nodo[node]["swpin"] = _series_puntos_nodo(rows, campo_sys="swpin")
        series_por_nodo[node]["swpout"] = _series_puntos_nodo(rows, campo_sys="swpout")
        series_por_nodo[node]["netr"] = _series_puntos_nodo(rows, campo_sys="netr")
        series_por_nodo[node]["netw"] = _series_puntos_nodo(rows, campo_sys="netw")
        series_por_nodo[node]["procs"] = _series_puntos_nodo(rows, campo_sys="procs")
        series_por_nodo[node]["nicerrors_sistema"] = _series_puntos_nodo(rows, campo_sys="nicerrors")

        # Red -- generalizado a TODOS los tipos de NIC vistos en el caso
        # (antes solo PRIVATE), nombrado "nic_<TIPO>_<metrica>" (p.ej.
        # nic_PUBLIC_kbps) para no pisar los nombres legacy de arriba.
        for tipo in tipos_nic:
            prefijo = f"nic_{tipo}_"
            series_por_nodo[node][prefijo + "kbps"] = _series_nic_tipo(rows, tipo, "kbps")
            series_por_nodo[node][prefijo + "latency_ms"] = _series_nic_tipo(rows, tipo, "latency_ms")
            series_por_nodo[node][prefijo + "discards"] = _series_nic_tipo(rows, tipo, "discards")
            series_por_nodo[node][prefijo + "link_errors"] = _series_nic_tipo(rows, tipo, "link_errors")
            series_por_nodo[node][prefijo + "pktsin"] = _series_nic_tipo(rows, tipo, "pktsin")
            series_por_nodo[node][prefijo + "pktsout"] = _series_nic_tipo(rows, tipo, "pktsout")
            series_por_nodo[node][prefijo + "nicerrors"] = _series_nic_tipo(rows, tipo, "nicerrors")

        # Protocolo -- los 9 contadores completos (antes solo 2 llegaban a
        # series_por_nodo), nombrados "proto_<contador>".
        proto_series = _series_proto_delta_nodo(rows)
        for nombre, puntos in proto_series.items():
            series_por_nodo[node][f"proto_{nombre}"] = puntos

        # Dispositivos -- una serie por (device, campo), nombrada
        # "dev::<nombre>::<campo>" (separador "::" a proposito: un nombre
        # de device real de oclumon nunca lo trae, a diferencia de ":" que
        # SI aparece en nombres tipo "Disk:sda"). Un device que no existe
        # en este nodo puntual queda con listas vacias (honesto: "sin
        # datos", nunca se inventa).
        for device_name in device_names:
            for campo in ("ior", "iow", "ios", "qlen", "wait_ms"):
                series_por_nodo[node][f"dev::{device_name}::{campo}"] = _series_dispositivo_nodo(
                    rows, device_name, campo,
                )

        # Filesystems -- una serie por (mount, campo), mismo separador que
        # devices. avail_mb/total_mb son MB (oclumon los da en KB).
        for mount in filesystem_mounts:
            for campo in ("used_pct", "avail_mb", "total_mb"):
                series_por_nodo[node][f"fs::{mount}::{campo}"] = _series_filesystem_nodo(
                    rows, mount, campo,
                )

    # Cortar visualmente periodos sin captura en TODAS las series. Se hace
    # al final para cubrir sistema, NIC, dispositivos y filesystems por igual.
    for datos_nodo in series_por_nodo.values():
        for clave, puntos in datos_nodo.items():
            datos_nodo[clave] = _insertar_huecos(puntos)

    # series_max: valor maximo real visto en CUALQUIER nodo para cada
    # serie -- a diferencia de series_relevantes (core/dashboard_engine.py,
    # "¿esta serie tiene al menos 1 punto?"), esto responde "¿ese punto
    # fue alguna vez >0?". Lo pide el audit externo del 2026-10-02 (punto
    # A.2, "graficos en cero permanente"): swpin/swpout/nicerrors_sistema
    # tenian puntos (una muestra por timestamp, como cualquier otra serie
    # de Sistema) pero en un caso sin swapping ni errores de NIC esos
    # puntos son todos 0 -- una linea plana en 0 durante todo el incidente
    # no aporta nada y antes se mostraba igual. El template gatea esos 3
    # paneles especificos con este diccionario ademas de series_relevantes.
    series_max = {}
    for datos_nodo in series_por_nodo.values():
        for clave, puntos in datos_nodo.items():
            if not puntos:
                continue
            valores = [p["v"] for p in puntos if p["v"] is not None]
            if not valores:
                continue
            pico = max(valores)
            if clave not in series_max or pico > series_max[clave]:
                series_max[clave] = pico

    log_cb(f"[episodios] {len(events)} eventos -> {len(episodios)} episodios narrados, "
           f"linea de tiempo con {len(timeline)} items")

    return {
        "node_list": sorted(nodes.keys()),
        "nic_types": tipos_nic,
        "nic_names_by_type": nic_names_by_type,
        "episodios": episodios,
        # Eventos discretos (uno por muestra que disparo una regla, antes
        # de agrupar en episodios) -- se exponen tal cual para que
        # core/dashboard_engine.py pueda armar una tabla de evidencias con
        # datos reales de oclumon, ahora que no hay alert log/trace del
        # que sacar esas filas.
        "eventos_discretos": events,
        "linea_tiempo": timeline,
        "proc_rankings": proc_rankings,
        "oclumon_diagnostics": diagnostics,
        "series_por_nodo": series_por_nodo,
        "series_max": series_max,
        "ventanas_captura": ventanas_captura,
        # Union global de nombres de device/filesystem -- alimenta los
        # selectores del panel OCLUMON "Dispositivos"/"Filesystems" (ver
        # templates/dashboard.html, seccion sec-oclumon). device_names ya
        # viene filtrado a los que tuvieron actividad real (ver nota mas
        # arriba); device_names_vistos_total es el conteo SIN filtrar.
        "device_names": device_names,
        "device_names_vistos_total": device_names_vistos_total,
        "filesystem_mounts": filesystem_mounts,
    }
