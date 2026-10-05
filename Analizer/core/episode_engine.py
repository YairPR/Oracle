"""Common OCLUMON samples, discontinuity-aware derived series and evidence-based episodes."""

import logging
from datetime import datetime, timezone
from statistics import median
from functools import lru_cache
from core.metric_contract import sum_known, contract
from core.oclumon_dataset import deduplicate

log = logging.getLogger("rac_forensic_lab.core.episode_engine")

MAX_UNPARSED_SAMPLES = 40
MAX_ERROR_SAMPLES = 40


@lru_cache(maxsize=65536)
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


def _insertar_huecos(puntos, cadence_seconds=None):
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
    paso = max(1, int(cadence_seconds if cadence_seconds is not None else median(rapidos)))
    umbral = paso * 3
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
    umbral = paso * 3
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
            "muestras_definicion": "timestamps únicos (no suma de registros por nodo)",
            "por_nodo": {node: len({_epoch_hora_origen(row["t"]) for row in rows
                                    if g[0] <= _epoch_hora_origen(row["t"]) <= g[-1]})
                         for node, rows in nodes.items()},
        }
        for g in grupos
    ]

# ---------------------------------------------------------------------
# Parser de oclumon (CHM) -- tokenizador generico, tolerante a version de
# GI (11g..19c), identico al de oclumon_analyzer.py. Ver docstring del
# modulo para por que NO se asume un orden/conjunto fijo de campos.
# ---------------------------------------------------------------------
def parse_oclumon_file(path):
    from core.oclumon_model import parse
    return parse(path)


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
    from core.oclumon_dataset import build
    return build(all_samples)


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
    "nic_discards": {"label": "Descartes en interfaz de red", "explica": "Tasa de descartes observada en la interfaz. Revisar tráfico, buffers y evidencia del driver; no identifica por sí sola una causa ni el rol de la NIC."},
    "nic_link_errors": {"label": "Errores de interfaz de red", "explica": "Tasa de errores errsin/errsout informada por la interfaz. Investigar contexto y driver; el rol de la NIC requiere evidencia independiente."},
    "nic_latency": {"label": "Latencia observada en interfaz de red", "explica": "Estimación reportada por CHM para esta interfaz; no equivale a latencia de operaciones RAC ni confirma un timeout."},
    "tcp_retrans": {"label": "Segmentos TCP retransmitidos", "explica": "Incrementos válidos del contador del host. Correlacionar con carga y errores; no atribuirlos a una NIC ni concluir impacto sin evidencia."},
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
    if cat in ("nic_discards", "nic_errors_hw", "nic_link_errors"):
        unit = "paquetes/s" if cat == "nic_discards" else "errores/s"
        return f"En {node}, entre {when}{span}, {ep.get('entity') or 'sistema'} informó una tasa máxima de {ep['peak_value']:g} {unit}; no es un volumen acumulado."
    if cat in ("ip_reasfail", "udp_rcverr", "tcp_retrans"):
        return (f"En {node}, entre {when}{span}, se acumularon +{int(ep['total_value'])} "
                f"(pico de +{int(ep['peak_value'])} en una sola muestra).")
    if cat == "interconnect_burst":
        return f"En {node}, entre {when}{span}, el trafico del interconnect llego a un pico de {ep['peak_value']:.0f} KB/s."
    if cat == "nic_latency":
        return f"En {node}, entre {when}{span}, la latencia observada de la interfaz llegó a un pico de {ep['peak_value']:.1f} ms."
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
    events=[]
    for node,rows in nodes.items():
        for row in rows:
            def add(cat,value,msg,entity=None,quality='observed',sev='warning'):
                events.append({'t':row['t'],'node':node,'sev':sev,'cat':cat,'value':value,
                    'msg':msg,'entity':entity,'quality':quality,'source': next((r.get('source') for r in row.get('devices',[])+row.get('nics',[])+row.get('filesystems',[]) if r.get('name',r.get('mount'))==entity),row.get('source')),
                    'line': next((r.get('line') for r in row.get('devices',[])+row.get('nics',[])+row.get('filesystems',[]) if r.get('name',r.get('mount'))==entity),row.get('line')),'segment':row.get('segment'),
                    'threshold_origin':'project heuristic; not an official Oracle limit'})
            sys=row.get('sys') or {}
            swap=sum_known(sys.get('swpin'),sys.get('swpout'))
            if swap is not None and swap>0:
                add('swap',swap,f"Swap activo: {swap:g} KB/s",sev='critical')
            if sys.get('cpuq') is not None and sys['cpuq']>=6:
                add('cpu_queue',sys['cpuq'],f"cpuq={sys['cpuq']:g}; heuristic threshold 6")
            if sys.get('nicerrors') is not None and sys['nicerrors']>0:
                add('nic_errors_hw',sys['nicerrors'],f"nicErrors={sys['nicerrors']:g}/s",sev='critical')
            for key,cat in [('ipreasfail','ip_reasfail'),('udprcverr','udp_rcverr'),('tcpretraseg','tcp_retrans')]:
                value=(row.get('proto_delta') or {}).get(key)
                if value is not None and value>0:
                    add(cat,value,f"{key} +{value:g}: host protocol counter",sev='warning')
            for nic in row.get('nics',[]):
                for fields,cat in [(('errsin','errsout'),'nic_link_errors'),(('indiscarded','outdiscarded'),'nic_discards')]:
                    value=sum_known(*(nic.get(k) for k in fields))
                    if value is not None and value>0:
                        add(cat,value,f"{nic['name']}: {cat} {value:g}/s",entity=nic['name'])
                if nic.get('latency_ms') is not None and nic['latency_ms']>=5:
                    add('nic_latency',nic['latency_ms'],f"{nic['name']}: observed NIC latency",entity=nic['name'])
            for dev in row.get('devices',[]):
                if 'OFFLINE' in (dev.get('type') or '').upper():
                    add('device_state',1,f"{dev['name']}: {dev['type']}",entity=dev['name'],sev='critical')
                if dev.get('wait_ms') is not None and dev['wait_ms']>=20:
                    add('device_wait',dev['wait_ms'],f"{dev['name']}: {dev['wait_ms']:g} ms observed interval mean",
                        entity=dev['name'],quality=dev.get('quality','observed'))
            for fs in row.get('filesystems',[]):
                value=fs.get('used_pct')
                if value is not None and value>=90:
                    add('fs_full',value,f"{fs['mount']}: {value:g}% source usage",entity=fs['mount'],sev='critical' if value>=95 else 'warning')
    return sorted(events,key=lambda e:_epoch_hora_origen(e['t']))


def build_episodios(events, gap_seconds=EPISODE_GAP_SECONDS):
    """Agrupa los eventos discretos (uno por muestra) en episodios
    contiguos por (nodo, categoria) y les agrega interpretacion +
    narrativa con los numeros reales agregados."""
    by_key = {}
    for e in events:
        by_key.setdefault((e["node"], e["cat"], e.get("entity"), e.get("segment")), []).append(e)

    episodes = []
    for (node, cat, entity, segment), evs in by_key.items():
        evs.sort(key=lambda e: e["t"])
        cur = None
        last_t = None
        for e in evs:
            t = datetime.fromisoformat(e["t"])
            if cur is None or (t - last_t).total_seconds() > gap_seconds:
                if cur is not None:
                    episodes.append(cur)
                cur = {
                    "node": node, "cat": cat, "sev": e["sev"], "entity": entity,
                    "quality": e.get("quality", "observed"), "threshold_origin": e.get("threshold_origin"),
                    "start": e["t"], "end": e["t"],
                    "n_samples": 0, "peak_value": 0.0, "total_value": 0.0,
                    "value_kind": "rate" if cat in ("nic_discards", "nic_link_errors", "nic_errors_hw", "swap") else "counter_increment" if cat in ("ip_reasfail", "udp_rcverr", "tcp_retrans") else "instantaneous",
                    "sample_msgs": [],
                }
            v = e.get("value", 0) or 0
            cur["end"] = e["t"]
            cur["n_samples"] += 1
            if v >= cur["peak_value"]:
                cur.update(peak_value=v, peak_time=e["t"], peak_source=e.get("source"), peak_line=e.get("line"))
            if e.get("quality") == "suspect": cur["quality"] = "suspect"
            if cur["value_kind"] == "counter_increment":
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
        if ep.get("quality") == "suspect":
            ep["interpretacion"] = "Valor extremo observado; causa y validez pendientes. No demuestra timeout ni corrupción."

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
            **{key:ep.get(key) for key in ("end","entity","peak_time","peak_value","quality","peak_line")},
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
    return {**{k:v for k,v in diag.items() if k not in ('sections','node_names','first_clock','last_clock','formats')},
        'sections': sections, 'node_names': sorted(diag['node_names']),
        'formats': sorted(diag.get('formats', [])),
        'first_clock': diag['first_clock'].isoformat() if diag['first_clock'] else None,
        'last_clock': diag['last_clock'].isoformat() if diag['last_clock'] else None}



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
        punto = {"t": t, "v": v}
        if campo_nic == "latency_ms_max" and nic and nic.get("latency_ms_max_lt"):
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
    # Delta was calculated once over the full source, before visual filtering.
    return {key:[{'t':_epoch_hora_origen(row['t']), 'v':(row.get('proto_delta') or {}).get(key)}
                 for row in rows] for key in PROTO_COUNTERS}


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
            v = eff if eff is not None else sum_known(nic["netrr"], nic["netwr"])
        elif metrica == "latency_ms":
            v = nic.get("latency_ms_max")
        elif metrica == "discards":
            v = sum_known(nic["indiscarded"], nic["outdiscarded"])
        elif metrica == "link_errors":
            v = sum_known(nic["errsin"], nic["errsout"])
        elif metrica == "pktsin":
            v = nic.get("pktsin")
        elif metrica == "pktsout":
            v = nic.get("pktsout")
        elif metrica == "nicerrors":
            v = nic.get("nicerrors")
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
        index = row.get('_device_index')
        if index is None:
            index = {}
            for device in row.get('devices') or []:
                index.setdefault(device.get('name'), device)
            row['_device_index'] = index
        v = index.get(device_name, {}).get(campo)
        out.append({"t": t, "v": v})
    return out


def _process_series(rows, timestamps, name, field):
    """All observed values; a null run keeps both boundaries, never becomes zero.

    Interior absent points carry no analytical value. Keeping the first/last
    absence preserves gaps and complete valid intervals for every window.
    Cadence is supplied from the original host clock, not this sparse series.
    """
    out = []
    last_null = None
    null_run = False
    for row, timestamp in zip(rows, timestamps):
        value = row.get('process_metrics', {}).get(name, {}).get(field)
        if value is None:
            if not null_run:
                out.append({'t': timestamp, 'v': None})
            last_null = timestamp
            null_run = True
            continue
        if null_run and last_null != out[-1]['t']:
            out.append({'t': last_null, 'v': None})
        out.append({'t': timestamp, 'v': value})
        null_run = False
    if null_run and last_null != out[-1]['t']:
        out.append({'t': last_null, 'v': None})
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
                if f.get('total_kb') is None or f['total_kb']<=0:
                    break
                if campo == "avail_mb":
                    raw = f.get("avail_kb")
                    v = (raw / 1024.0) if raw is not None else None
                elif campo == "total_mb":
                    raw = f.get("total_kb")
                    v = (raw / 1024.0) if raw is not None else None
                else:
                    v = f.get(campo)
                break
        out.append({"t": t, "v": v})
    return out


def nic_inventory(nodes):
    """Retain metadata changes and absence boundaries instead of repeated labels."""
    result = {}
    for node, rows in nodes.items():
        interfaces = result.setdefault(node, {})
        for row in rows:
            t = _epoch_hora_origen(row["t"])
            for nic in row.get("nics", []):
                if not nic.get("name"):
                    continue
                runs = interfaces.setdefault(nic["name"], [])
                previous = runs[-1] if runs else None
                if (previous and previous["type"] == nic["type"] and previous["mtu"] == nic.get("mtu")
                        and previous["segment"] == row["segment"] and t - previous["to"] <= row["cadence"] * 1.5):
                    previous["to"] = t
                else:
                    runs.append({"from": t, "to": t, "type": nic["type"], "mtu": nic.get("mtu"), "segment": row["segment"]})
    return result


def analizar_caso(oclumon_paths, log_cb=lambda s: None, normalizados=None):
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
            samples, diag, prank = (normalizados[path] if normalizados is not None
                                    else parse_oclumon_file(path))
            all_samples.extend(samples)
            diagnostics.append(serialize_diag(diag))
            merge_proc_rank(all_proc_rank, prank)
            log_cb(f"[episodios] {path}: {diag['samples']} muestra(s) oclumon parseadas")
        except Exception as e:
            log_cb(f"[episodios] ERROR parseando {path}: {e}")

    all_samples, duplicates = deduplicate(all_samples)
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
                if nombre not in actividad_device or pico > actividad_device[nombre]:
                    actividad_device[nombre] = pico
    device_names_vistos_total = len(actividad_device)
    device_names = sorted(
        actividad_device.keys(),
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

        for key in ("cpusys", "cpuuser", "cpuiowait", "cpusteal", "procs_blocked"):
            if any(key in (r.get("sys") or {}) for r in rows):
                series_por_nodo[node][key] = _series_puntos_nodo(rows, campo_sys=key)
        proto_series = _series_proto_delta_nodo(rows)
        for target,metric in [('interconnect_kbps','kbps'),('interconnect_nic_discards','discards'),('interconnect_nic_link_errors','link_errors')]:
            series_por_nodo[node][target]=_series_nic_tipo(rows,'PRIVATE',metric)
        series_por_nodo[node]['ip_reasfail']=proto_series['ipreasfail']
        series_por_nodo[node]['udp_rcverr']=proto_series['udprcverr']
        for key in ('ior','iow','ios'):
            series_por_nodo[node][key]=_series_puntos_nodo(rows,campo_sys=key)
        series_por_nodo[node]['memavl_gib']=_a_gib(_series_puntos_nodo(rows,campo_sys='memavl_mb'))
        for nicname in sorted({n['name'] for r in rows for n in r.get('nics',[]) if n.get('name')}):
            for field in ('netrr','netwr','pktsin','pktsout','errsin','errsout','indiscarded','outdiscarded','latency_ms'):
                points=[]
                for r in rows:
                    n=next((n for n in r.get('nics',[]) if n['name']==nicname),{})
                    point={'t':_epoch_hora_origen(r['t']),'v':n.get(field)}
                    if field=='latency_ms' and n.get('latency_lt'): point['lt']=True
                    points.append(point)
                series_por_nodo[node][f'nic::{nicname}::{field}']=points
        for cpu in sorted({str(c['id']) for r in rows for c in r.get('cpus',[]) if c.get('id')!='Total'}):
            series_por_nodo[node][f'cpu::{cpu}::usage']=[{'t':_epoch_hora_origen(r['t']),'v':next((c['usage'] for c in r.get('cpus',[]) if str(c['id'])==cpu),None)} for r in rows]
        timestamps = [_epoch_hora_origen(row['t']) for row in rows]
        for name in sorted({name for row in rows for name in row.get('process_metrics',{})}):
            for field in ('max_cpuusage','max_privmem_kb','max_shm_kb','max_fd','max_threads'):
                series_por_nodo[node][f'proc::{name}::{field}'] = _process_series(rows, timestamps, name, field)
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
    for node, datos_nodo in series_por_nodo.items():
        for clave, puntos in datos_nodo.items():
            datos_nodo[clave] = _insertar_huecos(puntos, nodes[node][0]['cadence'] if clave.startswith('proc::') else None)

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

    source_files=sorted({s["source"] for s in all_samples})
    source_ids={path:i for i,path in enumerate(source_files)}
    log_cb(f"[episodios] {len(events)} eventos -> {len(episodios)} episodios narrados, "
           f"linea de tiempo con {len(timeline)} items")

    return {
        "node_list": sorted(nodes.keys()),
        "duplicates": duplicates,
        "host_inventory": {n:next((s.get("inventory",{}) for s in reversed(all_samples) if s["node"]==n),{}) for n in nodes},
        "time_domains": sorted({s["clock"].strftime("%z") if s["clock"].tzinfo else "unknown" for s in all_samples}),
        "source_files": source_files,
        "trace_blocks": {n:[[_epoch_hora_origen(s["clock"]),source_ids[s["source"]],s["line"]] for s in all_samples if s["node"]==n] for n in nodes},
        "metric_contracts": {key:contract(key) for data in series_por_nodo.values() for key,points in data.items() if any(p.get("v") is not None for p in points)},
        "coverage": {n:{"samples":len(rows),"cadence_seconds":rows[0]["cadence"],"segments":max(r["segment"] for r in rows)} for n,rows in nodes.items()},
        "filesystem_quality": {n:sorted({f['mount'] for r in rows for f in r.get('filesystems',[]) if f.get('quality')=='capacity_unavailable'}) for n,rows in nodes.items()},
        "nic_inventory": nic_inventory(nodes),
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
