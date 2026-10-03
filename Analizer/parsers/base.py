"""
parsers/base.py

Contrato comun para todos los parsers de fuente del RAC Forensic Lab
(Hito 4+). Cada parser sabe leer UN formato (oclumon, alert log, trace,
sar, AWR, logs puros de Clusterware) y lo traduce a filas con la forma
exacta que espera `ForensicStorage.bulk_insert()` -- las mismas columnas
de la tabla `eventos_forenses`: timestamp, nodo, fuente, metrica_o_error,
valor, detalles.
"""

from abc import ABC, abstractmethod
from enum import Enum


class LogType(Enum):
    OCLUMON = "oclumon"
    ALERT_LOG = "alert_log"
    TRACE = "trace"
    SAR = "sar"
    AWR = "awr"
    CLUSTERWARE = "clusterware"
    UNKNOWN = "unknown"


class BaseParser(ABC):
    """Contrato que debe cumplir cualquier parser de fuente.

    log_type: que tipo de archivo sabe leer este parser (LogRouter lo usa
    para verificar que esta invocando el parser correcto para el tipo que
    detecto, no para que el parser se auto-detecte).

    parse(): hace el trabajo real. No debe lanzar por una linea/seccion
    mal formada dentro del archivo -- debe omitir esa parte y seguir,
    nunca abortar el archivo completo por un dato raro aislado (ver
    AwrParser para el patron de diagnostico recomendado: contar
    secciones encontradas/parseadas y guardar muestras de error, en vez
    de solo tragarse la excepcion en silencio).
    """

    log_type: LogType = LogType.UNKNOWN

    @abstractmethod
    def parse(self, file_path: str) -> list:
        """Lee file_path y devuelve list[dict], cada uno con las claves
        exactas timestamp (datetime o string ISO 8601), nodo, fuente,
        metrica_o_error, valor (float o None), detalles (str o None)."""
        raise NotImplementedError
