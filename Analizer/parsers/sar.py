"""
parsers/sar.py

Parser de salida de texto de `sar` (sysstat) -- tipicamente `sar -A` (todas
las secciones) o una combinacion de `sar -r` (memoria) + `sar -S` (swap)
redirigida a un archivo y copiada/pegada por el DBA. Extrae 3 metricas
pedidas explicitamente: % de memoria usada, % de swap usado, y memoria
libre en KB.

*** ESTADO: NO VERIFICADO CONTRA UN ARCHIVO REAL *** (2026-10-01). A
diferencia de AWR/Clusterware/oclumon/alert log/trace -- que se
calibraron o re-verificaron contra archivos reales del caso DEPT300 antes
de darlos por buenos -- todavia no se subio ninguna muestra real de `sar`.
Este modulo se construyo contra el formato de texto DOCUMENTADO y estable
de `sysstat` (el mismo que usan practicamente todas las distros RHEL/OEL
desde hace +15 anios), con la MISMA tecnica que ya probo su valor en
`parsers/awr.py`: ubicar la fila de encabezado real de cada tabla y mapear
columnas por NOMBRE/posicion en vez de contar espacios a mano o asumir un
ancho fijo. Aun asi, hasta que el usuario suba una muestra real de su
`sar` (version de sysstat, locale, exactamente que flags uso), este
parser debe tratarse como "mejor esfuerzo" -- si al correrlo contra una
muestra real los nombres de columna no calzan, `ultimo_diagnostico` lo va
a mostrar (lineas_totales vs filas_generadas = 0) en vez de fallar en
silencio, y hay que volver a calibrar exactamente como se hizo con AWR en
Hito 4.

Formato de texto esperado (sysstat estandar, locale en ingles):

    Linux 2.6.39-400.250.1.el5uek (bov-racsalud-301) 	09/30/2026 	_x86_64_	(6 CPU)

    12:00:01 AM kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit
    12:00:01 AM    123456   7890123     82.15    234567   8901234   9012345     45.23
    ...
    Average:        123456   7890123     82.15    234567   8901234   9012345     45.23

    12:00:01 AM kbswpfree kbswpused  %swpused  kbswpcad
    12:00:01 AM   2345678         0      0.00         0
    ...

La fecha base (MM/DD/YYYY) viene de la linea de cabecera del kernel (la
PRIMERA linea del archivo real de sysstat) -- cada fila de datos solo trae
hora (formato de 12h AM/PM, el formato por defecto sin `-T`/`-t`). Si la
hora de una fila es MENOR que la hora de la fila anterior (cruce de
medianoche dentro del mismo archivo), se asume que paso un dia -- heuristica
razonable para una coleccion de `sar` de 24h, documentada aca por si un
archivo real la contradice.

Que se guarda en DuckDB:
  - Seccion de memoria (identificada por traer la columna '%memused' en
    su fila de encabezado): MEM_USED_PCT (de '%memused'), MEM_FREE_KB
    (de 'kbmemfree').
  - Seccion de swap (identificada por traer '%swpused'): SWAP_USED_PCT
    (de '%swpused').
  - Las filas "Average:" (resumen, sin timestamp real) se omiten a
    proposito -- no son un punto en el tiempo, insertarlas inventaria un
    timestamp que no existe.
  - nodo: del hostname entre parentesis en la cabecera del kernel
    ("Linux ... (bov-racsalud-301) ..."). fuente: "sar".

Por pedido explicito: ninguna linea/seccion mal formada debe tumbar el
parseo completo.
"""

import re
import logging
from datetime import datetime, timedelta

from parsers.base import BaseParser, LogType

log = logging.getLogger("rac_forensic_lab.parsers.sar")

MAX_ERROR_SAMPLES = 20

RE_KERNEL_HEADER = re.compile(
    r"^Linux\s+\S+.*?\(([\w.-]+)\)\s+(\d{2}/\d{2}/\d{4})\s"
)
RE_TIME_12H = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\s*(AM|PM)\b\s*(.*)$")

# Columnas que identifican cada seccion -- se buscan por NOMBRE en la
# fila de encabezado (estilo flashdba, igual que parsers/awr.py), no por
# posicion fija, para tolerar columnas extra/distinto orden entre
# versiones de sysstat.
_COL_MEMUSED_PCT = "%memused"
_COL_MEMFREE = "kbmemfree"
_COL_SWPUSED_PCT = "%swpused"


def _es_fila_encabezado(tokens):
    return _COL_MEMUSED_PCT in tokens or _COL_SWPUSED_PCT in tokens


def _tipo_seccion(tokens):
    if _COL_MEMUSED_PCT in tokens:
        return "memoria"
    if _COL_SWPUSED_PCT in tokens:
        return "swap"
    return None


def _to_float(raw):
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


class SarParser(BaseParser):
    log_type = LogType.SAR

    def __init__(self):
        self.ultimo_diagnostico = None

    def parse(self, file_path: str) -> list:
        diag = {
            "path": file_path,
            "lineas_totales": 0,
            "fecha_base": None,
            "nodo_detectado": None,
            "secciones_detectadas": {"memoria": 0, "swap": 0},
            "filas_generadas": 0,
            "errors": [],
        }

        try:
            with open(file_path, encoding="utf-8", errors="replace") as f:
                lineas = [ln.rstrip("\n") for ln in f]
        except OSError as e:
            diag["errors"].append(f"no se pudo abrir el archivo: {e}")
            self.ultimo_diagnostico = diag
            return []

        fecha_base = None
        nodo = None
        for ln in lineas[:5]:
            m = RE_KERNEL_HEADER.match(ln)
            if m:
                nodo = m.group(1)
                try:
                    fecha_base = datetime.strptime(m.group(2), "%m/%d/%Y").date()
                except ValueError:
                    fecha_base = None
                break
        diag["nodo_detectado"] = nodo
        diag["fecha_base"] = fecha_base.isoformat() if fecha_base else None

        if fecha_base is None:
            diag["errors"].append(
                "no se encontro la linea de cabecera de kernel ('Linux ... (host) MM/DD/YYYY ...') "
                "en las primeras lineas -- sin fecha base no se puede construir un timestamp "
                "confiable, el archivo se clasifico como SAR pero no se puede parsear."
            )
            self.ultimo_diagnostico = diag
            return []

        rows = []
        col_actual = None  # lista de nombres de columna de la seccion activa
        tipo_actual = None  # "memoria" | "swap" | None
        dia_offset = 0
        ultima_hora = None

        for lineno, line in enumerate(lineas, start=1):
            diag["lineas_totales"] += 1
            if not line.strip():
                col_actual = None
                tipo_actual = None
                continue
            try:
                if line.strip().lower().startswith("average"):
                    # Fila de resumen, sin timestamp real -- se omite a
                    # proposito (ver docstring).
                    continue

                m = RE_TIME_12H.match(line.strip())
                if not m:
                    continue  # linea que no es ni encabezado de tabla ni fila de datos reconocida

                hh, mm, ss, ampm, resto = m.groups()
                tokens = resto.split()

                if _es_fila_encabezado(tokens):
                    tipo_actual = _tipo_seccion(tokens)
                    col_actual = tokens
                    diag["secciones_detectadas"][tipo_actual] = \
                        diag["secciones_detectadas"].get(tipo_actual, 0) + 1
                    # Cada seccion (CPU/memoria/swap/...) es su PROPIA
                    # serie de tiempo independiente que vuelve a arrancar
                    # en algo cercano a 00:00 -- el rollover de dia (ver
                    # mas abajo) no debe arrastrarse de una seccion a la
                    # siguiente, o un segundo bloque que tambien empieza
                    # a medianoche hereda por error el offset del bloque
                    # anterior.
                    dia_offset = 0
                    ultima_hora = None
                    continue

                if tipo_actual is None or col_actual is None:
                    continue  # fila de datos de una seccion que no nos interesa (CPU, red, etc)

                hora = int(hh) % 12
                if ampm == "PM":
                    hora += 12
                hora_actual = (hora, int(mm), int(ss))
                if ultima_hora is not None and hora_actual < ultima_hora:
                    dia_offset += 1
                ultima_hora = hora_actual

                ts = datetime.combine(fecha_base, datetime.min.time()) + \
                    timedelta(days=dia_offset, hours=hora, minutes=int(mm), seconds=int(ss))

                valores = dict(zip(col_actual, tokens))

                if tipo_actual == "memoria":
                    pct = _to_float(valores.get(_COL_MEMUSED_PCT))
                    if pct is not None:
                        rows.append({
                            "timestamp": ts, "nodo": nodo, "fuente": "sar",
                            "metrica_o_error": "MEM_USED_PCT", "valor": pct, "detalles": None,
                        })
                    libre = _to_float(valores.get(_COL_MEMFREE))
                    if libre is not None:
                        rows.append({
                            "timestamp": ts, "nodo": nodo, "fuente": "sar",
                            "metrica_o_error": "MEM_FREE_KB", "valor": libre, "detalles": None,
                        })
                elif tipo_actual == "swap":
                    pct = _to_float(valores.get(_COL_SWPUSED_PCT))
                    if pct is not None:
                        rows.append({
                            "timestamp": ts, "nodo": nodo, "fuente": "sar",
                            "metrica_o_error": "SWAP_USED_PCT", "valor": pct, "detalles": None,
                        })
            except Exception as e:
                if len(diag["errors"]) < MAX_ERROR_SAMPLES:
                    diag["errors"].append(f"L{lineno}: {e}")
                continue

        diag["filas_generadas"] = len(rows)
        self.ultimo_diagnostico = diag
        log.info(
            "SarParser %s: %d lineas, nodo=%s, fecha_base=%s, secciones=%s, "
            "%d fila(s) generadas, %d error(es) -- RECORDATORIO: parser no verificado "
            "contra un archivo sar real todavia.",
            file_path, diag["lineas_totales"], nodo, diag["fecha_base"],
            diag["secciones_detectadas"], len(rows), len(diag["errors"]),
        )
        return rows
