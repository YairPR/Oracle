"""
parsers/awr.py

Parser de reportes AWR en texto plano (awrrpt.sql, formato .txt -- NO el
.html).

*** HITO "FUSION DE MOTORES AWR" (2026-10-03) ***
Hasta este hito existian DOS extractores de AWR en el proyecto, construidos
en sesiones distintas sobre los mismos reportes reales de DEPT300:
  - Este archivo (bespoke: una regex a mano por seccion -- metadata, Load
    Profile, Top N Wait Events, OS Stats).
  - `rac_lab_v2/parsers/awr_secciones.py` (generico: corta CUALQUIER tabla
    de AWR a partir de su linea de guiones, con un helper _tabla()/
    _bloque_kv() reutilizable por seccion en vez de una regex nueva cada
    vez), con cobertura mucho mayor: Time Model, Efficiency, Wait Class
    completa, Wait Event Histogram, Service Statistics, Instance Activity
    Stats, Thread Activity, IOStat by Function, Interconnect Ping e
    Interconnect Device -- exactamente los datos que le faltaban al
    pipeline para el "Panel Tim Hall" (correlacion AAS/interconnect/
    gc-wait) que seguia pendiente en claude/rac_forensic_lab.md.

Mantener los dos era la deuda tecnica senalada por la auditoria que el
usuario pego ("dos motores de parseo para la misma fuente"). Este hito
LA CIERRA para AWR: el motor generico de `awr_secciones.py` se adopta
como UNICO extractor (clase `AwrSectionParser` mas abajo, portada aqui
casi sin cambios -- misma tecnica de corte por columnas, mismos helpers
_tabla()/_bloque_kv()/_cabecera(), calibrada contra los mismos AWR reales
de DEPT300, snaps 98889-98894). Lo que cambia es la CAPA DE COMPATIBILIDAD:
`parse()` y `parse_estructurado()` siguen devolviendo EXACTAMENTE la misma
forma que esperaban `core/storage.py`/`analizador.py` desde el Hito "Modelo
de datos dimensional" -- cero cambios en storage.py, ai/engine.py,
analizador.py o las plantillas del dashboard por este swap.

Mapeo deliberadamente conservador (por seguridad, sin datos reales para
verificar en esta sesion): `wait_events` en `parse_estructurado()` sale
SOLO de las filas `ambito="TOP"` (la tabla "Top N ... Events", equivalente
exacta a lo que el motor viejo ya extraia) -- las filas nuevas de
`ambito="FG"/"BG"` (Foreground/Background Wait Events completos, con su
propia columna "pct_tiempo" cuyo significado exacto -- "% of Total Call
Time" vs "% DB time" -- no se pudo confirmar sin un reporte real a mano en
esta sesion) NO se mezclan con el contrato existente para no arriesgar un
AAS/pct_dbtime silenciosamente incorrecto. Quedan disponibles sin usar en
`self.ultima_estructura_completa` (la salida completa y rica de
`AwrSectionParser.parse()`, con Time Model/Wait Class/Service Stats/
Interconnect Ping+Device/Histograma) para la fase 2 (wiring al dashboard),
que si necesita verificacion contra datos reales antes de prometerse.

*** ESTADO: CALIBRADO CONTRA REPORTES AWR REALES DEL CASO DEPT300 ***
(snaps 98877-98879 y 98889-98894, Oracle 11.2.0.4 RAC). Particularidades
reales toleradas por `AwrSectionParser` (ver su docstring interno): columna
"Tota Time" del Top N truncada a 4 caracteres ("219."), Wait Class truncada
a 10 caracteres ("Applicatio" -> se expande por prefijo contra la lista
oficial de 14 Wait Class de Oracle), nombres de evento truncados a 26/30
caracteres, tablas partidas en paginas con salto de forma (\\f) y cabecera
repetida.

Por pedido explicito del proyecto: ninguna seccion mal formada debe tumbar
el parseo completo -- cada seccion corre dentro de su propio try/except
(ver `sec()` en `AwrSectionParser.parse()`) y se registra en `diagnostico`
en vez de lanzar.
"""

from __future__ import annotations

import re
import logging
from datetime import datetime

from parsers.base import BaseParser, LogType

log = logging.getLogger("rac_forensic_lab.parsers.awr")

MAX_ERROR_SAMPLES = 20

_MESES = {"jan": 1, "ene": 1, "feb": 2, "mar": 3, "apr": 4, "abr": 4, "may": 5, "jun": 6,
          "jul": 7, "aug": 8, "ago": 8, "sep": 9, "set": 9, "oct": 10, "nov": 11, "dec": 12, "dic": 12}

WAIT_CLASSES = ["Administrative", "Application", "Cluster", "Commit", "Concurrency",
                "Configuration", "DB CPU", "Idle", "Network", "Other", "Queueing",
                "Scheduler", "System I/O", "User I/O"]

RE_DASH = re.compile(r"^[\s-]*-{3,}[\s-]*$")
RE_KV = re.compile(r"([A-Za-z][A-Za-z0-9 %()/\-\.,]*?)\s*:\s+(-?[\d,]*\.?\d+(?:E[+-]\d+)?)")

# Mismo diccionario de metricas de Load Profile que el motor viejo --
# etiqueta de Oracle (en minuscula, sin version-specific) -> clave interna
# que ya consumen core/storage.py/ai/engine.py/construir_payload().
LOAD_PROFILE_METRICS = {
    "db cpu(s)": "db_cpu_per_sec",
    "db cpu": "db_cpu_per_sec",
    "db time(s)": "db_time_per_sec",
    "db time": "db_time_per_sec",
    "logical reads": "logical_reads_per_sec",
    "logical read (blocks)": "logical_reads_per_sec",
    "physical reads": "physical_reads_per_sec",
    "physical read (blocks)": "physical_reads_per_sec",
    "physical writes": "physical_writes_per_sec",
    "physical write (blocks)": "physical_writes_per_sec",
    "parses (sql)": "parses_per_sec",
    "executes (sql)": "executes_per_sec",
}
OS_STATS_WANTED = {"NUM_CPUS", "BUSY_TIME", "IDLE_TIME", "IOWAIT_TIME"}


def parse_fecha_awr(txt):
    """'30-Sep-26 01:00:23' o '25-Dec-25 15:49' -> datetime, sin depender del locale
    (ver hallazgo de la auditoria externa sobre NLS_LANG/locale.setlocale)."""
    if not txt:
        return None
    m = re.match(r"(\d{1,2})-([A-Za-z]{3})-(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?", txt.strip())
    if not m:
        return None
    mes = _MESES.get(m.group(2).lower())
    if not mes:
        return None
    anio = int(m.group(3))
    anio += 2000 if anio < 100 else 0
    return datetime(anio, mes, int(m.group(1)), int(m.group(4)), int(m.group(5)), int(m.group(6) or 0))


def num(txt):
    """Numero AWR tolerante: comas, punto final truncado ('219.'), sufijos K/M/G, N/A."""
    if txt is None:
        return None
    t = str(txt).strip().replace(",", "")
    if not t or t.upper() in ("N/A", "-", "NULL"):
        return None
    mult = 1.0
    if t[-1] in "KMGT" and len(t) > 1:
        mult = {"K": 1e3, "M": 1e6, "G": 1e9, "T": 1e12}[t[-1]]
        t = t[:-1]
    if t.endswith("."):
        t = t[:-1]
    try:
        return float(t) * mult
    except ValueError:
        return None


def size_mb(txt):
    """Columnas 'Data' de IOStat: sufijos M,G,T en multiplos de 1024 -> MB."""
    if txt is None:
        return None
    t = str(txt).strip().replace(",", "")
    if not t or t.upper() == "N/A":
        return None
    f = {"K": 1 / 1024, "M": 1, "G": 1024, "T": 1024 ** 2}.get(t[-1])
    try:
        return float(t[:-1]) * f if f else float(t) / (1024 * 1024)
    except ValueError:
        return None


def expandir_wait_class(txt):
    if not txt:
        return None
    t = txt.strip()
    for wc in WAIT_CLASSES:
        if wc.lower().startswith(t.lower()):
            return wc
    return t


def _spans(linea_guiones):
    return [(m.start(), m.end()) for m in re.finditer(r"-+", linea_guiones)]


def _cortar(linea, spans):
    """Corta por tramos al estilo flashdba, tolerante a desbordes: la columna i va desde el
    fin del tramo anterior hasta el fin de su propio tramo (los numeros AWR van alineados a
    la derecha); la ultima columna llega hasta el final de la linea (texto como Wait Class)."""
    out = []
    for i, (s, e) in enumerate(spans):
        ini = 0 if i == 0 else spans[i - 1][1]
        fin = len(linea) if i == len(spans) - 1 else e
        out.append(linea[ini:fin].strip())
    return out


class AwrSectionParser:
    """Motor generico de extraccion (portado de rac_lab_v2/parsers/awr_secciones.py,
    ver aviso de fusion en el docstring del modulo). No implementa el contrato
    BaseParser directamente -- eso lo hace AwrParser, mas abajo, que lo envuelve."""

    def __init__(self):
        self.diagnostico = {}

    @staticmethod
    def _titulos(lineas, titulo):
        idx = []
        for i, l in enumerate(lineas):
            l2 = l.lstrip("\f")
            if l2.startswith(titulo):
                resto = l2[len(titulo):].lstrip()
                if resto == "" or resto.startswith("DB/Inst"):
                    idx.append(i)
        return idx

    def _tabla(self, lineas, titulo, max_busqueda=30):
        """Filas (listas de celdas) de todas las paginas de una tabla."""
        filas = []
        for i0 in self._titulos(lineas, titulo):
            j = i0 + 1
            while j < min(len(lineas), i0 + max_busqueda) and not RE_DASH.match(lineas[j]):
                j += 1
            if j >= len(lineas) or not RE_DASH.match(lineas[j]):
                continue
            sp = _spans(lineas[j])
            k = j + 1
            while k < len(lineas):
                l = lineas[k]
                if l.startswith("\f") or not l.strip() or RE_DASH.match(l):
                    break
                filas.append(_cortar(l, sp))
                k += 1
        return filas

    @staticmethod
    def _bloque_kv(lineas, titulo, max_lineas=40):
        """Bloques 'etiqueta: v1 [v2 ...]' (Load Profile, GC Load Profile, Efficiency)."""
        out = []
        for i0, l in enumerate(lineas):
            if l.lstrip("\f").startswith(titulo):
                for l2 in lineas[i0 + 1:i0 + 1 + max_lineas]:
                    if l2.startswith("\f"):
                        break
                    if not l2.strip():
                        if out:
                            break
                        continue
                    if set(l2.strip()) <= set("~- "):
                        continue
                    m = re.match(r"^\s*(.+?)\s*:\s+([-\d.,E+]+)((?:\s+[-\d.,E+]+)*)\s*$", l2)
                    if m and "   " not in m.group(1).strip():
                        vals = [m.group(2)] + m.group(3).split()
                        out.append((re.sub(r"\s+", " ", m.group(1).strip()), [num(v) for v in vals]))
                    else:
                        for mm in RE_KV.finditer(l2):
                            out.append((re.sub(r"\s+", " ", mm.group(1).strip()), [num(mm.group(2))]))
                break
        return out

    @staticmethod
    def _cabecera(lineas):
        cab = {}
        for i, l in enumerate(lineas[:40]):
            if l.startswith("DB Name") and i + 1 < len(lineas) and RE_DASH.match(lineas[i + 1]):
                c = _cortar(lineas[i + 2], _spans(lineas[i + 1]))
                cab.update(db_name=c[0], dbid=int(num(c[1]) or 0), instance_name=c[2],
                           instance_number=int(num(c[3]) or 0), startup_ts=parse_fecha_awr(c[4]),
                           release=c[5], rac=(c[6] if len(c) > 6 else None))
            elif l.startswith("Host Name") and i + 1 < len(lineas) and RE_DASH.match(lineas[i + 1]):
                c = _cortar(lineas[i + 2], _spans(lineas[i + 1]))
                cab.update(host=c[0], platform=c[1], cpus=num(c[2]), cores=num(c[3]),
                           sockets=num(c[4]), mem_gb=num(c[5]))
            else:
                m = re.match(r"^\s*(Begin|End) Snap:\s+(\d+)\s+(\S+ \S+)\s+(\d+)\s+([\d.]+)(?:\s+(\d+))?", l)
                if m:
                    p = "ini" if m.group(1) == "Begin" else "fin"
                    cab[f"snap_{p}"] = int(m.group(2))
                    cab[f"ts_{p}"] = parse_fecha_awr(m.group(3))
                    cab[f"sesiones_{p}"] = int(m.group(4))
                    cab[f"instancias_{p}"] = int(m.group(6)) if m.group(6) else None
                m = re.match(r"^\s*Elapsed:\s+([\d.,]+)", l)
                if m:
                    cab["elapsed_min"] = num(m.group(1))
                m = re.match(r"^\s*DB Time:\s+([\d.,]+)", l)
                if m:
                    cab["dbtime_min"] = num(m.group(1))
        return cab

    def parse(self, ruta):
        """Devuelve la estructura RICA completa (cabecera/load_profile/eficiencia/
        time_model/os_stat/wait_class/wait_event/histograma/servicio/actividad/
        thread/iostat/ic_ping/ic_device/diagnostico) -- ver AwrParser.parse_estructurado()
        mas abajo para la capa de compatibilidad que el resto del pipeline consume hoy."""
        with open(ruta, encoding="utf-8", errors="replace") as fh:
            texto = fh.read().replace("\r", "")
        lineas = texto.split("\n")
        r = {"archivo": str(ruta)}
        diag = {"secciones_ok": [], "secciones_vacias": [], "avisos": []}

        def sec(nombre, fn, vacio=None):
            try:
                v = fn()
                (diag["secciones_ok"] if v else diag["secciones_vacias"]).append(nombre)
                return v
            except Exception as e:  # nunca tumbar el pipeline por una seccion
                diag["avisos"].append(f"{nombre}: {type(e).__name__}: {e}")
                return [] if vacio is None else vacio

        r["cabecera"] = sec("Cabecera", lambda: self._cabecera(lineas), vacio={})
        if not r["cabecera"].get("snap_ini"):
            diag["avisos"].append("No se reconocio la cabecera AWR (Begin/End Snap)")

        def _lp():
            out = []
            for seccion, titulo in (("load", "Load Profile"), ("gc", "Global Cache Load Profile")):
                for k, v in self._bloque_kv(lineas, titulo):
                    out.append(dict(seccion=seccion, metrica=k, por_seg=v[0],
                                    por_txn=v[1] if len(v) > 1 else None,
                                    por_exec=v[2] if len(v) > 2 else None,
                                    por_call=v[3] if len(v) > 3 else None))
            return out
        r["load_profile"] = sec("Load Profile", _lp)

        r["eficiencia"] = sec("Efficiency", lambda: [
            dict(seccion=s, metrica=k, valor=v[0])
            for s, t in (("instancia", "Instance Efficiency Percentages"),
                         ("gc", "Global Cache Efficiency Percentages"),
                         ("gc_workload", "Global Cache and Enqueue Services - Workload"))
            for k, v in self._bloque_kv(lineas, t)])

        r["time_model"] = sec("Time Model", lambda: [
            dict(estadistica=f[0], tiempo_s=num(f[1]), pct_dbtime=num(f[2]) if len(f) > 2 else None)
            for f in self._tabla(lineas, "Time Model Statistics") if f and f[0]])

        r["os_stat"] = sec("OS Statistics", lambda: [
            dict(estadistica=f[0], valor=num(f[1]), valor_fin=num(f[2]) if len(f) > 2 else None)
            for f in self._tabla(lineas, "Operating System Statistics") if f and f[0]])

        m = re.search(r"Captured Time accounts for\s+([\d.]+)%", texto)
        r["cabecera"]["captured_pct"] = float(m.group(1)) if m else None
        r["wait_class"] = sec("Foreground Wait Class", lambda: [
            dict(wait_class=expandir_wait_class(f[0]), waits=num(f[1]), pct_timeouts=num(f[2]),
                 tiempo_s=num(f[3]), avg_ms=num(f[4]), pct_dbtime=num(f[5]) if len(f) > 5 else None)
            for f in self._tabla(lineas, "Foreground Wait Class") if f and f[0]])

        def _ev(titulo, ambito):
            return [dict(ambito=ambito, evento=f[0], waits=num(f[1]), pct_timeouts=num(f[2]),
                         tiempo_s=num(f[3]), avg_ms=num(f[4]), waits_txn=num(f[5]),
                         pct_tiempo=num(f[6]) if len(f) > 6 else None, wait_class=None,
                         truncado=len(f[0]) >= 26)
                    for f in self._tabla(lineas, titulo) if f and f[0] and len(f) >= 6]

        def _top():
            filas = self._tabla(lineas, "Top 10 Foreground Events by Total Wait Time") \
                or self._tabla(lineas, "Top 5 Timed Foreground Events")
            out = []
            for f in filas:
                if not f or not f[0]:
                    continue
                out.append(dict(ambito="TOP", evento=f[0], waits=num(f[1]), pct_timeouts=None,
                                tiempo_s=num(f[2]), avg_ms=num(f[3]), waits_txn=None,
                                pct_tiempo=num(f[4]) if len(f) > 4 else None,
                                wait_class=(expandir_wait_class(f[5]) if len(f) > 5 and f[5]
                                            else ("DB CPU" if f[0] == "DB CPU" else None)),
                                truncado=len(f[0]) >= 30))
            return out
        r["wait_event"] = (sec("Top Events", _top)
                           + sec("Foreground Wait Events", lambda: _ev("Foreground Wait Events", "FG"))
                           + sec("Background Wait Events", lambda: _ev("Background Wait Events", "BG")))

        def _hist():
            out = []
            for i0 in self._titulos(lineas, "Wait Event Histogram"):
                j = i0 + 1
                while j < min(len(lineas), i0 + 20) and not (RE_DASH.match(lineas[j])
                                                            and len(_spans(lineas[j])) >= 5):
                    j += 1
                if j >= min(len(lineas), i0 + 20):
                    continue
                sp = _spans(lineas[j])
                buckets = _cortar(lineas[j - 1], sp)[2:]
                k = j + 1
                while k < len(lineas) and lineas[k].strip() and not lineas[k].startswith("\f") \
                        and not RE_DASH.match(lineas[k]):
                    c = _cortar(lineas[k], sp)
                    for b, v in zip(buckets, c[2:]):
                        if v.strip():
                            out.append(dict(evento=c[0], total_waits=num(c[1]), bucket=b, pct_waits=num(v)))
                    k += 1
            return out
        r["histograma"] = sec("Wait Event Histogram", _hist)

        r["servicio"] = sec("Service Statistics", lambda: [
            dict(servicio=f[0], dbtime_s=num(f[1]), dbcpu_s=num(f[2]),
                 phys_reads_k=num(f[3]), logical_reads_k=num(f[4]))
            for f in self._tabla(lineas, "Service Statistics") if f and f[0] and len(f) >= 5])

        def _act():
            out, vistos = [], set()
            for t in ("Key Instance Activity Stats", "Other Instance Activity Stats", "Instance Activity Stats"):
                for f in self._tabla(lineas, t):
                    if f and f[0] and f[0] not in vistos and len(f) >= 2:
                        vistos.add(f[0])
                        out.append(dict(estadistica=f[0], total=num(f[1]),
                                        por_seg=num(f[2]) if len(f) > 2 else None,
                                        por_txn=num(f[3]) if len(f) > 3 else None))
            return out
        r["actividad"] = sec("Instance Activity Stats", _act)

        def _thr():
            m = re.search(r"log switches \(derived\)\s+([\d,]+)\s+([\d.,]+)", texto)
            return [dict(log_switches=num(m.group(1)), por_hora=num(m.group(2)))] if m else []
        r["thread"] = sec("Thread Activity", _thr)

        r["iostat"] = sec("IOStat by Function", lambda: [
            dict(funcion=f[0], lectura_mb=size_mb(f[1]), lectura_req_s=num(f[2]), lectura_mb_s=size_mb(f[3]),
                 escritura_mb=size_mb(f[4]), escritura_req_s=num(f[5]), escritura_mb_s=size_mb(f[6]),
                 waits=num(f[7]), avg_ms=num(f[8]) if len(f) > 8 else None)
            for f in self._tabla(lineas, "IOStat by Function summary") if f and f[0] and len(f) >= 8])

        r["ic_ping"] = sec("Interconnect Ping Latency", lambda: [
            dict(instancia_destino=int(num(f[0])), n_500b=num(f[1]), avg_500b_ms=num(f[2]),
                 sd_500b_ms=num(f[3]), n_8k=num(f[4]), avg_8k_ms=num(f[5]), sd_8k_ms=num(f[6]))
            for f in self._tabla(lineas, "Interconnect Ping Latency Stats")
            if f and num(f[0]) is not None and len(f) >= 7])

        def _dev():
            out = []
            for i0 in self._titulos(lineas, "Interconnect Device Statistics"):
                k = i0 + 1
                while k < min(len(lineas), i0 + 60):
                    m = re.match(r"^(\S+)\s+(\d+\.\d+\.\d+\.\d+)\s*(.*)$", lineas[k])
                    if m and k + 2 < len(lineas):
                        s = [num(x) for x in lineas[k + 1].split()] + [None] * 5
                        rv = [num(x) for x in lineas[k + 2].split()] + [None] * 5
                        resto = m.group(3).strip()
                        pub = resto.split()[0] if resto.split() and resto.split()[0] in ("YES", "NO") else None
                        out.append(dict(dispositivo=m.group(1), ip=m.group(2), publica=pub,
                                        origen=resto[len(pub):].strip() if pub else resto,
                                        envio_mb_s=s[0], envio_err=s[1], envio_drop=s[2], envio_overrun=s[3],
                                        carrier_lost=s[4], recep_mb_s=rv[0], recep_err=rv[1],
                                        recep_drop=rv[2], recep_overrun=rv[3], frame_err=rv[4]))
                        k += 3
                        continue
                    if lineas[k].startswith("\f") or lineas[k].lstrip().startswith("Dynamic Remastering"):
                        break
                    k += 1
            return out
        r["ic_device"] = sec("Interconnect Device Statistics", _dev)

        self.diagnostico = diag
        r["diagnostico"] = diag
        return r


class AwrParser(BaseParser):
    """Envoltorio BaseParser alrededor de AwrSectionParser (ver aviso de
    fusion arriba). `log_type`/`parse()`/`parse_estructurado()` mantienen
    exactamente el contrato que ya consumen core/storage.py, ai/engine.py,
    analizador.py y las plantillas del dashboard -- este swap de motor
    interno no les exige ningun cambio."""

    log_type = LogType.AWR

    def __init__(self):
        self.ultimo_diagnostico = None
        # Estructura rica completa del ultimo archivo parseado (todas las
        # secciones que extrae AwrSectionParser, incluidas las que
        # parse_estructurado() todavia no expone al resto del pipeline --
        # Time Model, Wait Class completa, Service Stats, Instance
        # Activity, IOStat by Function, Interconnect Ping/Device,
        # Histograma). Disponible para la fase 2 (wiring al dashboard,
        # "Panel Tim Hall") sin tener que re-parsear el archivo.
        self.ultima_estructura_completa = None

    # -- forma rica (nueva) ----------------------------------------------
    def parse_completo(self, file_path: str) -> dict:
        r = AwrSectionParser().parse(file_path)
        self.ultima_estructura_completa = r
        self.ultimo_diagnostico = r["diagnostico"]
        return r

    # -- forma dimensional (contrato existente, Hito "Modelo de datos
    # dimensional") -------------------------------------------------------
    @staticmethod
    def _estructura_vacia(file_path, diag):
        return {
            "infraestructura": {
                "host": None, "cpus": None, "cores": None, "sockets": None,
                "mem_gb": None, "num_cpus": None, "busy_time": None,
                "idle_time": None, "iowait_time": None,
            },
            "database": {
                "host": None, "db_name": None, "instance_name": None,
                "release": None, "rac": None,
            },
            "snapshot": {
                "host": None, "awr_file": file_path,
                "begin_snap_id": None, "end_snap_id": None,
                "begin_ts": None, "end_ts": None,
                "db_cpu_per_sec": None, "db_time_per_sec": None,
                "logical_reads_per_sec": None, "physical_reads_per_sec": None,
                "physical_writes_per_sec": None,
                "parses_per_sec": None, "executes_per_sec": None,
                "num_cpus": None, "busy_time": None,
                "idle_time": None, "iowait_time": None,
            },
            "wait_events": [],
            "diagnostico": diag,
        }

    def parse_estructurado(self, file_path: str) -> dict:
        """Mismo contrato de salida que el motor viejo (infraestructura/
        database/snapshot/wait_events/diagnostico), ahora derivado de la
        estructura rica de AwrSectionParser. `wait_events` sale SOLO de
        las filas ambito="TOP" (equivalente exacto a lo que ya extraia el
        motor anterior) -- ver aviso de seguridad en el docstring del
        modulo sobre por que FG/BG no se mezclan aca todavia."""
        try:
            r = self.parse_completo(file_path)
        except OSError as e:
            diag = {"secciones_ok": [], "secciones_vacias": [], "avisos": [f"no se pudo abrir el archivo: {e}"]}
            self.ultimo_diagnostico = diag
            return self._estructura_vacia(file_path, diag)

        cab = r["cabecera"]
        diag = r["diagnostico"]
        host = cab.get("host")

        os_stats = {d["estadistica"].lower(): d["valor"] for d in r["os_stat"]
                    if d.get("estadistica") in OS_STATS_WANTED and d.get("valor") is not None}

        load = {}
        for fila in r["load_profile"]:
            if fila.get("seccion") != "load":
                continue
            clave = LOAD_PROFILE_METRICS.get((fila.get("metrica") or "").lower())
            if clave and fila.get("por_seg") is not None:
                load[clave] = fila["por_seg"]

        wait_events = [
            {
                "evento": f["evento"],
                "wait_class": f.get("wait_class"),
                "waits": f.get("waits"),
                "tiempo_s": f.get("tiempo_s"),
                "pct_dbtime": f.get("pct_tiempo"),
            }
            for f in r["wait_event"] if f.get("ambito") == "TOP"
        ]

        infraestructura = {
            "host": host,
            "cpus": cab.get("cpus"),
            "cores": cab.get("cores"),
            "sockets": cab.get("sockets"),
            "mem_gb": cab.get("mem_gb"),
            "num_cpus": os_stats.get("num_cpus"),
            "busy_time": os_stats.get("busy_time"),
            "idle_time": os_stats.get("idle_time"),
            "iowait_time": os_stats.get("iowait_time"),
        }
        database = {
            "host": host,
            "db_name": cab.get("db_name"),
            "instance_name": cab.get("instance_name"),
            "release": cab.get("release"),
            "rac": cab.get("rac"),
        }
        snapshot = {
            "host": host,
            "awr_file": file_path,
            "begin_snap_id": cab.get("snap_ini"),
            "end_snap_id": cab.get("snap_fin"),
            "begin_ts": cab.get("ts_ini"),
            "end_ts": cab.get("ts_fin"),
            "db_cpu_per_sec": load.get("db_cpu_per_sec"),
            "db_time_per_sec": load.get("db_time_per_sec"),
            "logical_reads_per_sec": load.get("logical_reads_per_sec"),
            "physical_reads_per_sec": load.get("physical_reads_per_sec"),
            "physical_writes_per_sec": load.get("physical_writes_per_sec"),
            "parses_per_sec": load.get("parses_per_sec"),
            "executes_per_sec": load.get("executes_per_sec"),
            "num_cpus": os_stats.get("num_cpus"),
            "busy_time": os_stats.get("busy_time"),
            "idle_time": os_stats.get("idle_time"),
            "iowait_time": os_stats.get("iowait_time"),
        }

        self.ultimo_diagnostico = diag
        return {
            "infraestructura": infraestructura,
            "database": database,
            "snapshot": snapshot,
            "wait_events": wait_events,
            "diagnostico": diag,
        }

    # -- forma plana (contrato BaseParser, compatibilidad) ----------------
    def parse(self, file_path: str) -> list:
        """BaseParser exige este metodo; ya no es el camino que usa
        analizador.py (ver _ingerir_awr(), que llama parse_estructurado()),
        pero se mantiene funcional por si algun llamador externo todavia
        depende de la forma plana timestamp/nodo/fuente/metrica_o_error/
        valor/detalles."""
        estructura = self.parse_estructurado(file_path)
        host = estructura["snapshot"]["host"]
        ref_ts = estructura["snapshot"]["begin_ts"] or estructura["snapshot"]["end_ts"] or datetime.now()
        rows = []

        meta = estructura["database"]
        snap = estructura["snapshot"]
        for metrica, valor_txt in (
            ("hostname", host), ("instance_name", meta.get("instance_name")),
            ("db_version", meta.get("release")), ("begin_snap_id", snap.get("begin_snap_id")),
            ("end_snap_id", snap.get("end_snap_id")),
        ):
            if valor_txt is None:
                continue
            rows.append({
                "timestamp": ref_ts, "nodo": host, "fuente": "awr", "metrica_o_error": metrica,
                "valor": float(valor_txt) if metrica.endswith("snap_id") else None,
                "detalles": str(valor_txt),
            })

        for metrica, valor in (
            ("db_cpu_per_sec", snap["db_cpu_per_sec"]), ("db_time_per_sec", snap["db_time_per_sec"]),
            ("logical_reads_per_sec", snap["logical_reads_per_sec"]),
            ("physical_reads_per_sec", snap["physical_reads_per_sec"]),
            ("physical_writes_per_sec", snap["physical_writes_per_sec"]),
            ("parses_per_sec", snap["parses_per_sec"]), ("executes_per_sec", snap["executes_per_sec"]),
        ):
            if valor is not None:
                rows.append({"timestamp": ref_ts, "nodo": host, "fuente": "awr",
                             "metrica_o_error": metrica, "valor": valor, "detalles": "Load Profile"})

        for ev in estructura["wait_events"]:
            detalles = f"wait_class={ev['wait_class']}" if ev.get("wait_class") else None
            for sufijo, valor in (("waits", ev["waits"]), ("tiempo_s", ev["tiempo_s"]), ("pct_dbtime", ev["pct_dbtime"])):
                if valor is not None:
                    rows.append({"timestamp": ref_ts, "nodo": host, "fuente": "awr",
                                 "metrica_o_error": f"wait_event_{sufijo}:{ev['evento']}",
                                 "valor": valor, "detalles": detalles})

        for stat_lower, valor in (
            ("num_cpus", snap["num_cpus"]), ("busy_time", snap["busy_time"]),
            ("idle_time", snap["idle_time"]), ("iowait_time", snap["iowait_time"]),
        ):
            if valor is not None:
                rows.append({"timestamp": ref_ts, "nodo": host, "fuente": "awr",
                             "metrica_o_error": stat_lower, "valor": valor, "detalles": None})

        log.info("AwrParser %s: %d filas planas generadas (compatibilidad), %d avisos",
                  file_path, len(rows), len(estructura["diagnostico"].get("avisos", [])))
        return rows
