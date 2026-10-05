"""
parsers/oclumon.py

Parser de dumps de OS/CHM (Cluster Health Monitor) -- la salida de
`oclumon dumpnodeview` que ya tenia su propio motor completo y probado en
oclumon_analyzer.py (el analizador de campo). Este modulo NO reimplementa
ese motor entero (que cubre SYSTEM/TOP/NICS/PROTO/DEVICES/FILESYSTEMS/
PROCESSES para un reporte HTML interactivo) -- es deliberadamente mas
angosto: solo extrae las metricas pedidas explicitamente para este
pipeline de DuckDB (CPU, IO wait, 2 contadores de PROTOCOL ERRORS), con la
MISMA logica de tokenizado y de deteccion de bloque ya verificada en el
analizador de campo (portada tal cual, no reinventada).

*** ESTADO: PORTADO Y RE-VERIFICADO CONTRA EL DUMP REAL DEL CASO DEPT300
*** (2026-10-01, chm_nodo2.txt -- el mismo archivo que ya se uso en la
calibracion de clasificacion de Hito 4). Formato real confirmado linea
por linea contra ese archivo antes de escribir este modulo:

  Cada "muestra" (sample) empieza con una linea divisoria
  "----------------------------------------" seguida de una linea con
  los campos 'Node:'/'Clock:'/'SerialNo:' en cualquier orden, p.ej.:

      Node: bov-racsalud-302 Clock: '09-29-26 11.38.00' SerialNo:14041604

  (igual que oclumon_analyzer.py, la deteccion de "esto es el inicio de
  una muestra nueva" se hace por la PRESENCIA de 'Node' y 'Clock' como
  tokens, no por exigir un formato de linea divisoria exacto -- mas
  tolerante entre versiones de GI). 'Clock' viene como
  "MM-DD-YY HH.MM.SS" (confirmado: "09-29-26 11.38.00" cae en
  2026-09-29, la misma fecha real del incidente DEPT300 segun el alert
  log -- consistencia cruzada confirmada entre fuentes).

  Debajo de cada cabecera de muestra vienen secciones con su propio
  encabezado en mayusculas ("SYSTEM:", "PROTOCOL ERRORS:", etc, ver
  SECTION_HEADERS). Este parser solo mira 2 de esas secciones:

    SYSTEM: una sola linea "clave: valor" repetida -- confirmado real:
      "...cpu: 4.85 cpuq: 1 ... ior: 1042 iow: 531 ios: 242 swpin: 0
      swpout: 0 ... swapfree: 22609916 swaptotal: 22609916 ..."
      Se extraen 'cpu' (-> CPU_USAGE_PCT, % de uso de CPU) e 'ior'/'iow'/'ios'
      -- ver CORRECCION DE ETIQUETADO mas abajo, estas 3 NO son "I/O wait"
      (% de CPU esperando I/O) como se las llamo originalmente, sino tasas
      de I/O en disco.

    PROTOCOL ERRORS: una sola linea "clave: valor" repetida -- confirmado
      real: "IPHdrErr: 0 IPAddrErr: 56 IPUnkProto: 0 IPReasFail: 1094505
      IPFragFail: 36 TCPFailedConn: 1831 TCPEstRst: 2393846
      TCPRetraSeg: 107846226 ...". Se extraen 'IPReasFail'
      (-> NET_IP_REASM_FAIL) y 'TCPRetraSeg' (-> NET_TCP_RETRA_SEG), las
      2 metricas pedidas explicitamente. OJO -- confirmado contra el
      dump real: son CONTADORES ACUMULATIVOS desde que arranco el
      daemon (crecen o se mantienen, nunca bajan, entre muestras
      sucesivas del mismo nodo) -- se guardan tal cual, crudos, en
      DuckDB; cualquier "salto" hay que calcularlo como delta entre
      muestras consecutivas en SQL (ver ai/engine.RootCauseEngine,
      calcular_estado_salud()), nunca asumiendo que el valor absoluto
      por si solo significa algo.

  Ampliacion deliberada mas alla de lo pedido literalmente en el punto 2
  del hito, necesaria para que el punto 3 (deteccion de "uso activo de
  SWAP") sea posible: tambien se extrae de SYSTEM un tercer metrica,
  SWAP_USED_MB = (swaptotal - swapfree) en MB -- confirmado real que
  ambos campos SI estan en la misma linea SYSTEM ("swapfree: 22609916
  swaptotal: 22609916", en KB, de ahi la conversion /1024). Sin esta
  metrica, el motor de salud (Hito de esta misma tanda) no tendria
  ningun dato de swap en DuckDB para evaluar ese criterio -- se declara
  aca explicitamente en vez de dejarlo como un gap silencioso.

Nodo: viene directo del campo 'Node:' de cada muestra -- a diferencia de
alert log/Clusterware, oclumon SIEMPRE trae esto explicito, no hace falta
adivinar por convencion de path ni por archivo.

*** CORRECCION DE ETIQUETADO (2026-10-01, hallazgo de la auditoria tecnica,
ver claude/analisis_tecnico_pipeline.md) ***
La version anterior de este parser tomaba el campo 'iow' de SYSTEM y lo
guardaba como metrica "IO_WAIT", asumiendo implicitamente que era
equivalente al '%iowait' de `sar -u` o al IOWAIT_TIME que reporta AWR
(ambos son tiempo de CPU esperando I/O, un PORCENTAJE/conteo de tiempo de
CPU). Es una confusion real: segun la documentacion oficial de Oracle
("oclumon dumpnodeview", Tabla "SYSTEM View Metric Descriptions", y "OS
Metrics Collected by Cluster Health Monitor", consistente en 12c/19c/21c),
'ior'/'iow'/'ios' en la seccion SYSTEM de CHM son:
  - ior: tasa promedio de LECTURA de disco en el intervalo de muestra, en
    KB/s.
  - iow: tasa promedio de ESCRITURA de disco en el intervalo de muestra,
    en KB/s.
  - ios: tasa promedio de OPERACIONES de I/O en el intervalo de muestra,
    en operaciones/s (IOPS).
Es decir, los 3 son contadores de THROUGHPUT de disco, no porcentajes de
tiempo de CPU -- comparar "IO_WAIT" (en realidad KB/s de escritura) contra
el IOWAIT_TIME real que ya extrae correctamente parsers/awr.py (ese si es
tiempo de CPU, tal cual lo reporta V$OSSTAT) hubiera sido comparar
unidades incompatibles sin ningun aviso. Se corrige guardando las 3 bajo
nombres que reflejan lo que realmente miden: IO_READ_RATE_KBPS,
IO_WRITE_RATE_KBPS, IO_OPS_PER_SEC -- ninguna de las 3 se llama ya
"IO_WAIT", para que no se confunda por nombre con la metrica de AWR/sar
que SI mide espera de CPU. Ningun consumidor existente (ai/engine.py,
core/correlacion.py, core/episode_engine.py) leia la metrica vieja
"IO_WAIT" -- se verifico por grep antes de renombrar -- asi que este
cambio no rompe ninguna query ya probada.

Por pedido explicito: ninguna linea/muestra mal formada debe tumbar el
parseo completo del archivo.
"""

import re
import logging
from datetime import datetime

from parsers.base import BaseParser, LogType

log = logging.getLogger("rac_forensic_lab.parsers.oclumon")

MAX_ERROR_SAMPLES = 20

# Tokenizador generico "clave: valor" -- IDENTICO a TOKEN_RE de
# oclumon_analyzer.py (misma logica probada: valores entre comillas
# simples se devuelven sin ellas, sin exigir orden ni set fijo de
# campos).
_TOKEN_RE = re.compile(r"([#A-Za-z][\w#%]*)\s*:\s*('[^']*'|-?\d+\.\d+|-?\d+|\S+)")

_SECTION_HEADERS = {
    "SYSTEM:": "system",
    "PROTOCOL ERRORS:": "proto",
    # El resto de secciones reales (TOP CONSUMERS/PROCESSES/DEVICES/
    # FILESYSTEMS/NICS) se reconocen igual (para no perder la cuenta de
    # lineas totales ni confundir sus valores con los de SYSTEM/PROTO),
    # pero no se extraen -- fuera del alcance pedido en este hito.
    "TOP CONSUMERS:": "otra",
    "PROCESSES:": "otra",
    "DEVICES:": "otra",
    "FILESYSTEMS:": "otra",
    "NICS:": "otra",
}

_RE_CLOCK = re.compile(r"(\d\d)-(\d\d)-(\d\d)\s+(\d\d)\.(\d\d)\.(\d\d)")


def _tokenize(line: str):
    out = {}
    for m in _TOKEN_RE.finditer(line):
        key, val = m.group(1), m.group(2)
        if len(val) >= 2 and val.startswith("'") and val.endswith("'"):
            val = val[1:-1]
        out[key] = val
    return out


def _parse_clock(s: str):
    """'MM-DD-YY HH.MM.SS' -> datetime (anio + 2000). None si no matchea
    o si los numeros no forman una fecha valida -- replica parse_clock()
    de oclumon_analyzer.py."""
    m = _RE_CLOCK.match(s.strip())
    if not m:
        return None
    mo, d, y, h, mi, se = map(int, m.groups())
    y += 2000
    try:
        return datetime(y, mo, d, h, mi, se)
    except ValueError:
        return None


def _as_float(toks: dict, key: str):
    v = toks.get(key)
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


class OclumonParser(BaseParser):
    log_type = LogType.OCLUMON

    def __init__(self):
        self.ultimo_diagnostico = None

    def parse(self, file_path: str) -> list:
        """One full CHM read; storage and episodes share the normalized samples."""
        from core.episode_engine import parse_oclumon_file
        self.ultimo_normalizado = parse_oclumon_file(file_path)
        samples, diag, _ = self.ultimo_normalizado
        self.ultimo_diagnostico = diag
        self.lectura_perfil = {"lectura_seg": diag.get("lectura_seg", 0.0)}
        return [
            {"timestamp": sample["clock"], "nodo": sample["node"], "fuente": "oclumon",
             "metrica_o_error": metric, "valor": value, "detalles": None}
            for sample in samples for metric, value in sample["telemetria"]
        ]
