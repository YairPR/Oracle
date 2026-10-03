"""
core/router.py

Enrutador inteligente de archivos (Hito 4). Clasifica un archivo por
firma semantica (contenido real de los primeros 2 KB), no por extension
ni por nombre -- igual que el analizador de campo nunca confio en el
nombre del archivo para saber a que nodo pertenecia un dump de oclumon,
aqui tampoco se confia en que alguien haya nombrado el archivo "awr.txt".
El nombre de carpeta solo entra como ULTIMO recurso si el contenido no
concluye nada con claridad.

*** HITO "rediseno AWR + tabs + LogRouter acotado" (2026-10-02) ***
Instruccion explicita del usuario: "LogRouter solo debe ver awr, oclumon
o sar que son las unicas metricas del proyecto". Se eliminaron las firmas
de contenido y los hints de carpeta de ALERT_LOG/CLUSTERWARE/TRACE (codigo
"fantasma" desde el Hito de simplificacion de alcance, 2026-10-01 --
ninguna de esas 3 fuentes tiene parser conectado en PARSERS de
analizador.py desde entonces, asi que un archivo de ese tipo siempre
terminaba en "clasificado pero sin parser conectado, se omite" de todas
formas; este hito solo hace que el router deje de intentar distinguirlas
entre si, cayendo directo a UNKNOWN). `LogType` (parsers/base.py) sigue
declarando esos valores -- no se tocan, otros modulos los referencian --
pero `detect_file_type()` nunca los devuelve mas.

Nota de honestidad sobre que tan solidas son las firmas de abajo (actualizada
tras la calibracion con datos reales del caso DEPT300, 2026-10-01):
  - OCLUMON: verificada contra archivos reales desde la Fase 1/2 (son
    literalmente las mismas constantes que ya usa oclumon_analyzer.py,
    reutilizadas aqui para no tener dos definiciones del mismo formato
    divergiendo con el tiempo).
  - AWR: verificada contra 2 reportes AWR reales del caso (awrrpt_1_98878_98879
    y awrrpt_1_98877_98878) -- el titulo real es "WORKLOAD REPOSITORY report
    for" (con "report" en minuscula, de ahi re.IGNORECASE) y "Snap Id" aparece
    tal cual en la tabla de metadata.
  - SAR: sigue SIN verificar contra un archivo real -- no se subio
    todavia ninguna muestra de `sar`. La firma de abajo (cabecera de
    kernel "Linux ... (N CPU)" o filas con hora de 12h AM/PM) se
    construyo contra el formato documentado y estable de sysstat, igual
    criterio best-effort que ya se uso para AWR antes de su calibracion
    -- ver parsers/sar.py para el detalle. Si un archivo sar real se
    clasifica mal, es el primer lugar a mirar.
"""

import os
import re

from parsers.base import LogType

_HEAD_BYTES = 2048

# ---- OCLUMON -- mismas constantes que oclumon_analyzer.py (verificadas
# contra archivos reales de dump de CHM del caso DEPT300). ----
_RE_OCLUMON_SYSTEM_TIME = re.compile(r"SYSTEM TIME:")
_RE_OCLUMON_NODE = re.compile(r"\bNode:\s*\S+")
_RE_OCLUMON_CLOCK = re.compile(r"\bClock:\s*\S+")

# ---- AWR -- titulo real confirmado contra 2 reportes AWR reales del caso:
# "WORKLOAD REPOSITORY report for" (nota: "report" en minuscula en los
# reportes reales de 11.2.0.4 -- de ahi el re.IGNORECASE, que ademas cubre
# sin costo cualquier version que lo capitalice distinto). "Snap Id"
# tambien confirmado tal cual en la tabla de metadata de ambos reportes. ----
_RE_AWR_TITLE = re.compile(r"WORKLOAD REPOSITORY REPORT", re.IGNORECASE)
_RE_AWR_SNAPID = re.compile(r"\bSnap Id\b")

# ---- SAR -- encabezado de kernel Linux (primera linea de un sar en
# texto plano) y columnas de hora con AM/PM (formato sin -T de sysstat).
# No verificado contra un archivo real todavia. ----
_RE_SAR_KERNEL = re.compile(r"^Linux\s+\S+.*\(\d+\s*CPU\)", re.MULTILINE)
_RE_SAR_AMPM_TIME = re.compile(r"\b\d{2}:\d{2}:\d{2}\s*(?:AM|PM)\b")

# Fallback por nombre de carpeta -- solo se usa si el contenido no
# concluyo nada. Coincide con los nombres de carpeta que el propio
# usuario ya usa para organizar evidencia (ver estructura del caso
# DEPT300: dumps y logs agrupados por tipo).
_FOLDER_HINTS = {
    "oclumon": LogType.OCLUMON,
    "chm": LogType.OCLUMON,
    "sar": LogType.SAR,
    "sysstat": LogType.SAR,
    "awr": LogType.AWR,
}


class LogRouter:
    """Clasifica archivos de evidencia por firma semantica en vez de por
    extension o nombre. Sin estado -- una instancia se puede reusar
    libremente para clasificar muchos archivos."""

    def detect_file_type(self, file_path: str) -> LogType:
        head = self._read_head(file_path)
        if head is None:
            return LogType.UNKNOWN

        detected = self._detect_from_content(head)
        if detected is not LogType.UNKNOWN:
            return detected

        return self._detect_from_path(file_path)

    def _read_head(self, file_path: str):
        """Lee los primeros 2 KB de forma segura: errors='replace' para
        que un byte invalido (encoding mixto, binario accidental) nunca
        tumbe la clasificacion -- en el peor caso se pierden unos pocos
        caracteres ilegibles, nunca se lanza una excepcion."""
        try:
            with open(file_path, encoding="utf-8", errors="replace") as f:
                return f.read(_HEAD_BYTES)
        except OSError:
            return None

    def _detect_from_content(self, head: str) -> LogType:
        # AWR primero: es la firma mas inconfundible (titulo literal de
        # un reporte oficial), y un AWR puede tener timestamps/lineas
        # que de otra forma podrian matchear alert log o trace por
        # casualidad si se revisara despues.
        if _RE_AWR_TITLE.search(head) or _RE_AWR_SNAPID.search(head):
            return LogType.AWR

        if _RE_OCLUMON_SYSTEM_TIME.search(head) or (
            _RE_OCLUMON_NODE.search(head) and _RE_OCLUMON_CLOCK.search(head)
        ):
            return LogType.OCLUMON

        if _RE_SAR_KERNEL.search(head) or _RE_SAR_AMPM_TIME.search(head):
            return LogType.SAR

        return LogType.UNKNOWN

    def _detect_from_path(self, file_path: str) -> LogType:
        parts = [p.lower() for p in os.path.normpath(file_path).split(os.sep)]
        for part in parts:
            if part in _FOLDER_HINTS:
                return _FOLDER_HINTS[part]
        return LogType.UNKNOWN
