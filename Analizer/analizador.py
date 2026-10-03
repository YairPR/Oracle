"""
analizador.py

Punto de entrada del RAC Forensic Lab. Recibe la carpeta de un caso,
clasifica cada archivo con LogRouter (por firma de contenido, no por
nombre/extension), parsea e inserta en DuckDB (esquema dimensional de 8
tablas, ver core/storage.py -- AWR via parse_estructurado()/4 tablas
dedicadas, oclumon/sar via bulk_insert_telemetria() sobre
fact_telemetria_so), y arma el dashboard HTML autocontenido
(templates/dashboard.html via core/html_builder.py) como
`informe_incidente.html` dentro de la propia carpeta del caso.

*** HITO "MODELO DE DATOS DIMENSIONAL" (2026-10-02) ***
Hasta este hito, TODO (oclumon/sar/awr) se volcaba en una sola tabla
plana `eventos_forenses`. Tras una auditoria externa (AUDIT_ANTI.txt)
que señalo ese anti-patron, `core/storage.py` se reescribio con 8 tablas
dimensionales (dim_caso/dim_infraestructura/dim_database/
fact_telemetria_so/fact_awr_snapshots/fact_awr_wait_events/fact_timeline/
kb_vectores). Este archivo se reconecto a ese esquema nuevo: cada corrida
registra su caso en dim_caso (_caso_id_de_carpeta(), el nombre de la
carpeta), AWR pasa por _ingerir_awr() (reparte su contenido en 4 tablas
dimensionales), oclumon/sar siguen igual que siempre pero ahora
insertando en fact_telemetria_so (mismas columnas que eventos_forenses +
caso_id). construir_payload() (mas abajo) tambien se migro: como AWR ya
no vive en una tabla de filas planas, las consultas que alimentan
"Calidad de datos"/"Tabla cruda" (Fuentes, rango de tiempo, tabla de
eventos) ahora UNEN fact_telemetria_so con una vista aplanada de las 2
tablas de AWR (ver _sql_eventos_unificados() mas abajo) -- el usuario
sigue viendo exactamente el mismo contenido en esos paneles, aunque por
debajo el dato ya vive en tablas tipadas. ai/engine.py se migro en un
proceso separado para consultar las tablas dimensionales directo (sin
pasar por esa vista aplanada) donde tiene sentido hacerlo (AWR ya no
necesita el parseo de string "wait_event_waits:<evento>" para separar
sus 3 metricas, por ejemplo).

*** ALCANCE (Hito de simplificacion, 2026-10-01, decision explicita del
usuario -- "solo series de telemetria: oclumon, sar, awr") ***
El pipeline quedo acotado a 3 fuentes: AWR (parsers/awr.py), oclumon/CHM
(parsers/oclumon.py) y `sar` (parsers/sar.py). alert log, Clusterware y
trace de proceso individual se retiraron del pipeline (dependian de
codigos ORA-/CRS- y patrones de texto que ya no se consumen aca) -- ver
claude/rac_forensic_lab.md para el detalle de que se quito y por que.

Tambien desde este hito: la IA (Ollama) ya NO corre automaticamente
dentro de este pipeline (era el cuello de botella real, ~230s medidos) --
solo el contexto SQL rapido (hechos_telemetria + estado_salud) se calcula
siempre. La consulta libre a Ollama es a pedido, vía el modo `--servir`
(servidor HTTP local + endpoint /api/preguntar, ver main()).

Uso:
    python analizador.py /ruta/a/la/carpeta/del/caso [--db caso_analisis.duckdb] [--servir [puerto]]
    py analizador.py <ruta_de_windows_a_la_carpeta_del_caso> --db caso_analisis.duckdb   (Windows, via el ejecutor 'py')
"""

import os
import sys
import time
import argparse
import logging
from datetime import datetime

import duckdb

from core.router import LogRouter
from core.storage import ForensicStorage
from parsers.base import LogType
from parsers.awr import AwrParser
from parsers.oclumon import OclumonParser
from parsers.sar import SarParser
from ai.engine import RootCauseEngine
from core.episode_engine import analizar_caso as analizar_episodios
from core.dashboard_engine import construir_informe
from core.html_builder import render_dashboard

log = logging.getLogger("rac_forensic_lab.analizador")

# Que parser usar por cada LogType. Alcance acotado a 3 fuentes (ver
# aviso arriba) -- lo que no sea AWR/OCLUMON/SAR cae sin parser
# conectado (LogType.CLUSTERWARE/ALERT_LOG/TRACE/UNKNOWN), ver
# ingerir_carpeta() mas abajo.
PARSERS = {
    LogType.AWR: AwrParser,
    LogType.OCLUMON: OclumonParser,
    LogType.SAR: SarParser,
}

NOMBRE_INFORME_SALIDA = "informe_incidente.html"
LIMITE_EVENTOS_TABLA = 50000  # tope defensivo para la tabla cruda de Evidencias -- ver construir_payload()


def clasificar_carpeta(carpeta: str, router: LogRouter) -> dict:
    """Recorre la carpeta (recursivo) y devuelve {LogType: [paths]}."""
    por_tipo = {}
    for root, _dirs, files in os.walk(carpeta):
        for name in files:
            path = os.path.join(root, name)
            tipo = router.detect_file_type(path)
            por_tipo.setdefault(tipo, []).append(path)
    return por_tipo


def _caso_id_de_carpeta(carpeta: str) -> str:
    """El nombre de la carpeta del caso es el identificador estable de
    dim_caso -- correr el analisis 2 veces sobre la misma carpeta (mismo
    .duckdb o uno nuevo) siempre registra el mismo caso_id. No se usa un
    UUID a proposito: un nombre legible ('caso_dept300_real') es mas util
    para inspeccionar la base a mano con SQL que un identificador opaco."""
    return os.path.basename(os.path.normpath(carpeta)) or carpeta


def _ingerir_awr(storage: ForensicStorage, caso_id: str, parser: AwrParser,
                  path: str, log_cb) -> int:
    """Camino de ingesta especifico de AWR (Hito 'Modelo de datos
    dimensional', 2026-10-02): a diferencia de oclumon/sar (filas planas
    genericas -> bulk_insert_telemetria), un AWR se parsea con
    parse_estructurado() y reparte su contenido en 4 tablas dimensionales
    (dim_infraestructura/dim_database/fact_awr_snapshots/
    fact_awr_wait_events) -- ver core/storage.py y parsers/awr.py para el
    contrato completo. Devuelve una cuenta de "filas equivalentes"
    (infraestructura + database + snapshot + wait events) solo para que
    el resumen/instrumentacion de tiempos de ingerir_carpeta() siga
    teniendo un numero que reportar por archivo, igual que antes.

    Si el archivo no se pudo ni abrir (host/db_name/wait_events todos
    vacios), no inserta nada -- mismo criterio de "nunca fabricar una
    fila sin datos reales" que ya aplicaba el camino plano viejo."""
    estructura = parser.parse_estructurado(path)
    infra = estructura["infraestructura"]
    base = estructura["database"]
    snap = estructura["snapshot"]
    wait_events = estructura["wait_events"]

    algo_util = (
        infra.get("host") or base.get("db_name") or snap.get("begin_ts")
        or snap.get("db_cpu_per_sec") is not None or wait_events
    )
    if not algo_util:
        log_cb(f"[awr] {path}: 0 datos extraidos "
               f"(diagnostico: {estructura.get('diagnostico')})")
        return 0

    n = 0
    if infra.get("host") is not None or any(
        infra.get(k) is not None for k in
        ("cpus", "cores", "sockets", "mem_gb", "num_cpus", "busy_time", "idle_time", "iowait_time")
    ):
        storage.insertar_infraestructura(caso_id=caso_id, **infra)
        n += 1
    if base.get("db_name") is not None or base.get("instance_name") is not None:
        storage.insertar_database(caso_id=caso_id, **base)
        n += 1
    snapshot_id = storage.insertar_awr_snapshot(caso_id=caso_id, **snap)
    n += 1
    if wait_events:
        n += storage.bulk_insert_wait_events(
            caso_id=caso_id, snapshot_id=snapshot_id, host=snap.get("host"), eventos=wait_events,
        )
    return n


def ingerir_carpeta(carpeta: str, db_path: str, log_cb=print) -> dict:
    """Clasifica + parsea + inserta en DuckDB. log_cb recibe cada linea de
    progreso (print por defecto en CLI; gui.py le pasa un callback propio
    para volcar todo a su consola en pantalla). Devuelve un resumen dict
    -- nunca lanza por un archivo individual mal formado (ver manejo de
    excepciones mas abajo), pero SI deja propagar un error de verdad
    irrecuperable (p.ej. no se pudo ni abrir el .duckdb de salida).

    Instrumentacion de tiempo (agregada 2026-10-01, pedido explicito del
    usuario -- "la performance se demora 5 minutos... quiero saber que
    consume el tiempo"): se mide el tiempo de clasificacion, el de CADA
    archivo individual (parse + bulk_insert) y el total de ingesta, y se
    devuelven en el dict de resumen bajo 'tiempos' -- la hipotesis de
    trabajo (todavia sin confirmar con una medicion real del usuario) es
    que esta fase es rapida y el cuello de botella real esta en la
    inferencia local de Ollama dentro de RootCauseEngine (ver
    ejecutar_caso_completo), pero sin numeros reales eso seria una
    suposicion, no un diagnostico -- de ahi la instrumentacion."""
    t_inicio_total = time.monotonic()
    router = LogRouter()
    t0 = time.monotonic()
    por_tipo = clasificar_carpeta(carpeta, router)
    t_clasificacion = time.monotonic() - t0

    log_cb("== Clasificacion de archivos ==")
    for tipo, paths in sorted(por_tipo.items(), key=lambda kv: kv[0].value):
        log_cb(f"  {tipo.value}: {len(paths)} archivo(s)")
        for p in paths:
            log_cb(f"    - {p}")

    caso_id = _caso_id_de_carpeta(carpeta)
    total_insertadas = 0
    con_parser = 0
    sin_parser = 0
    tiempos_por_archivo = []  # [{"path", "tipo", "segundos", "filas"}, ...] -- para diagnostico de performance
    with ForensicStorage(db_path) as storage:
        if storage.filas_eliminadas_al_conectar:
            # Ver nota de idempotencia en core/storage.py -- se reporta
            # tambien por log_cb (no solo por logging.warning) porque es
            # la consola que el usuario SI ve, tanto en el CLI como en
            # gui.py (que ya configura logging.basicConfig(), ver fix en
            # gui.py, pero esto no depende de eso).
            log_cb(f"AVISO: {storage.filas_eliminadas_al_conectar} fila(s) de una corrida "
                   f"anterior sobre {db_path} se eliminaron antes de esta ingesta (cada "
                   f"corrida reprocesa la carpeta completa -- usa un --db distinto si "
                   f"querias conservar la corrida anterior).")
        storage.registrar_caso(caso_id, nombre=caso_id)
        for tipo, paths in por_tipo.items():
            ParserCls = PARSERS.get(tipo)
            if ParserCls is None:
                # En la practica (2026-10-01) solo LogType.UNKNOWN cae
                # aca -- las 6 fuentes reales del ecosistema Oracle RAC ya
                # tienen parser conectado (ver diccionario PARSERS arriba).
                log_cb(f"[{tipo.value}] clasificado pero sin parser conectado a este "
                       f"pipeline todavia -- se omite ({len(paths)} archivo(s)).")
                sin_parser += len(paths)
                continue
            parser = ParserCls()
            for path in paths:
                t_archivo_inicio = time.monotonic()
                try:
                    # AWR tiene su propio camino de ingesta (Hito "Modelo
                    # de datos dimensional", 2026-10-02): reparte su
                    # contenido en 4 tablas dimensionales en vez de filas
                    # planas genericas -- ver _ingerir_awr() mas arriba.
                    # oclumon/sar NO cambian: siguen devolviendo filas
                    # planas (list[dict]) que van a fact_telemetria_so
                    # (mismo rol que la vieja eventos_forenses, solo con
                    # caso_id agregado al estampar).
                    if tipo == LogType.AWR:
                        n = _ingerir_awr(storage, caso_id, parser, path, log_cb)
                        filas = None  # no aplica el log generico de "0 filas" de abajo
                    else:
                        filas = parser.parse(path)
                        n = 0
                except Exception as e:
                    # Un parser no deberia lanzar (ver contrato en
                    # BaseParser.parse) pero esto es la ultima red de
                    # seguridad: un archivo problematico no debe tumbar
                    # el resto del caso.
                    log_cb(f"[{tipo.value}] ERROR inesperado parseando {path}: {e}")
                    continue
                if filas is not None:
                    if filas:
                        n = storage.bulk_insert_telemetria(caso_id, filas)
                    else:
                        log_cb(f"[{tipo.value}] {path}: 0 filas extraidas "
                               f"(diagnostico: {getattr(parser, 'ultimo_diagnostico', None)})")
                total_insertadas += n
                con_parser += 1
                t_archivo = time.monotonic() - t_archivo_inicio
                tiempos_por_archivo.append({
                    "path": path, "tipo": tipo.value, "segundos": round(t_archivo, 3), "filas": n,
                })
                if n:
                    tabla = "fact_telemetria_so" if tipo != LogType.AWR else "tablas dimensionales de AWR"
                    log_cb(f"[{tipo.value}] {path}: {n} filas insertadas en {tabla} "
                           f"({t_archivo:.2f}s)")

    t_total = time.monotonic() - t_inicio_total
    log_cb(f"Total: {total_insertadas} filas insertadas en {db_path} ({t_total:.2f}s de ingesta)")
    # Los 5 archivos mas lentos, para que el DBA vea de un vistazo donde
    # se le va el tiempo sin tener que leer el log completo.
    tiempos_por_archivo.sort(key=lambda d: d["segundos"], reverse=True)
    if tiempos_por_archivo:
        log_cb("  Archivos mas lentos de esta ingesta:")
        for d in tiempos_por_archivo[:5]:
            log_cb(f"    {d['segundos']:.2f}s  [{d['tipo']}]  {d['path']}  ({d['filas']} filas)")

    return {
        "por_tipo": {t.value: len(p) for t, p in por_tipo.items()},
        "total_insertadas": total_insertadas,
        "archivos_con_parser": con_parser,
        "archivos_sin_parser": sin_parser,
        "tiempos": {
            "clasificacion_seg": round(t_clasificacion, 3),
            "total_seg": round(t_total, 3),
            "por_archivo": tiempos_por_archivo,
        },
        # Rutas crudas por tipo (no solo el conteo) -- agregado para que
        # ejecutar_caso_completo() pueda alimentar el motor de episodios
        # (core/episode_engine.py, 2026-10-01) con los mismos archivos
        # oclumon/alert_log que ya clasifico LogRouter aca arriba, sin
        # tener que recorrer la carpeta una segunda vez.
        "rutas_por_tipo": {t.value: list(p) for t, p in por_tipo.items()},
    }


# ---------------------------------------------------------------------
# Motor de episodios (core/episode_engine.py) -- deteccion de anomalias +
# agrupacion en episodios narrados + series por nodo, portado del
# analizador de campo (oclumon_analyzer.py). Funciona DIRECTO sobre los
# archivos oclumon crudos (no sobre DuckDB). Desde el Hito de
# simplificacion de alcance ya NO consume alert log (ver aviso en el
# docstring del modulo).
# ---------------------------------------------------------------------

def ejecutar_motor_episodios(oclumon_paths: list, log_cb=print) -> dict:
    """Envoltorio de analizar_caso() (core/episode_engine.py) con la misma
    red de seguridad que el resto del pipeline: NUNCA lanza. Si no hay
    archivos oclumon en el caso (p.ej. un caso que solo trae AWR),
    devuelve una estructura vacia pero con la misma forma, para que
    construir_payload() no tenga que andar comprobando None en cada
    campo. Si analizar_caso() en si lanza algo inesperado (no deberia --
    ya tiene su propio manejo de excepciones por archivo, ver su
    docstring), se captura aca como ultima red de seguridad."""
    vacio = {
        "node_list": [], "nic_types": [], "episodios": [], "eventos_discretos": [],
        "linea_tiempo": [], "proc_rankings": {}, "oclumon_diagnostics": [],
        "series_por_nodo": {}, "series_max": {}, "device_names": [],
        "device_names_vistos_total": 0, "filesystem_mounts": [],
    }
    if not oclumon_paths:
        log_cb("[episodios] sin archivos oclumon en este caso -- "
               "motor de episodios omitido (nada que analizar).")
        return vacio
    try:
        return analizar_episodios(oclumon_paths=oclumon_paths, log_cb=log_cb)
    except Exception as e:
        log_cb(f"[episodios] ERROR inesperado en el motor de episodios: {e} "
               f"-- el resto del informe se genera igual, sin episodios/linea de tiempo narrada.")
        return vacio


# ---------------------------------------------------------------------
# Hito 6, Sub-tarea 6.3 -- payload del dashboard + escritura del informe.
# ---------------------------------------------------------------------

def _epoch_seg(dt) -> int:
    """datetime -> segundos epoch (int), formato que espera el eje de
    tiempo de uPlot. Nunca lanza -- si dt no es un datetime real, se
    omite el punto en el llamador (ver _serie_puntos)."""
    return int(dt.timestamp())


# Metricas numericas de fact_awr_snapshots (incluye las 2 columnas
# GENERATED, aas/db_time_seg/elapsed_seg -- DuckDB las deja leer en un
# SELECT como cualquier otra) que _sql_eventos_unificados() aplana de
# vuelta a la forma plana legada (timestamp/nodo/fuente/metrica_o_error/
# valor/detalles) para que "Calidad de datos"/"Tabla cruda" sigan
# mostrando el mismo contenido que mostraban sobre la vieja
# eventos_forenses, aunque AWR ya no viva en una tabla de filas planas.
_AWR_SNAPSHOT_METRICAS = (
    "db_cpu_per_sec", "db_time_per_sec", "logical_reads_per_sec",
    "physical_reads_per_sec", "physical_writes_per_sec",
    "num_cpus", "busy_time", "idle_time", "iowait_time",
    "elapsed_seg", "db_time_seg", "aas",
)
# Las 3 metricas de wait event que antes vivian como 3 filas separadas
# por evento (wait_event_waits:<evento> / wait_event_tiempo_s:<evento> /
# wait_event_pct_dbtime:<evento>) -- mismo prefijo de nombre que usaba el
# parser viejo, para que una busqueda de texto en "Tabla cruda" siga
# encontrando lo mismo que antes. avg_wait_ms (GENERATED) se agrega como
# una 4ta fila nueva -- antes no existia, es una mejora aditiva.
_AWR_WAIT_EVENT_CAMPOS = (
    ("waits", "wait_event_waits"),
    ("tiempo_s", "wait_event_tiempo_s"),
    ("pct_dbtime", "wait_event_pct_dbtime"),
    ("avg_wait_ms", "wait_event_avg_wait_ms"),
)


def _sql_eventos_unificados() -> str:
    """SQL (una subconsulta, para envolver en WITH o usar inline) que
    reconstruye la forma plana legada (timestamp/nodo/fuente/
    metrica_o_error/valor/detalles) uniendo fact_telemetria_so (oclumon/
    sar, sin cambios) con una vista aplanada de fact_awr_snapshots +
    fact_awr_wait_events (cada metrica numerica no-NULL de AWR se
    convierte en 1 fila, 'awr' como fuente) -- ver nota de este Hito en
    el docstring del modulo. Solo la usan los 3 paneles de
    'calidad de datos'/'tabla cruda' del dashboard (construir_payload);
    ai/engine.py consulta las tablas dimensionales DIRECTO, sin pasar por
    esta vista."""
    ramas_snapshot = "\nUNION ALL\n".join(
        f"SELECT coalesce(begin_ts, end_ts) AS timestamp, host AS nodo, 'awr' AS fuente, "
        f"'{metrica}' AS metrica_o_error, {metrica} AS valor, NULL AS detalles "
        f"FROM fact_awr_snapshots WHERE {metrica} IS NOT NULL"
        for metrica in _AWR_SNAPSHOT_METRICAS
    )
    ramas_wait = "\nUNION ALL\n".join(
        f"SELECT coalesce(s.begin_ts, s.end_ts) AS timestamp, w.host AS nodo, 'awr' AS fuente, "
        f"'{prefijo}:' || w.evento AS metrica_o_error, w.{campo} AS valor, "
        f"CASE WHEN w.wait_class IS NOT NULL THEN 'wait_class=' || w.wait_class END AS detalles "
        f"FROM fact_awr_wait_events w JOIN fact_awr_snapshots s ON s.snapshot_id = w.snapshot_id "
        f"WHERE w.{campo} IS NOT NULL"
        for campo, prefijo in _AWR_WAIT_EVENT_CAMPOS
    )
    return (
        "SELECT timestamp, nodo, fuente, metrica_o_error, valor, detalles FROM fact_telemetria_so\n"
        "UNION ALL\n" + ramas_snapshot + "\nUNION ALL\n" + ramas_wait
    )


def _inyectar_series_sar(con, resultado_episodios: dict) -> None:
    """Hito 'Sistema Operativo (SAR)' (2026-10-02): el motor de episodios
    (core/episode_engine.py) calcula series_por_nodo DIRECTO sobre los
    archivos oclumon crudos -- nunca toco DuckDB ni SAR. En vez de
    duplicar ese motor para una fuente con solo 3 metricas, se inyectan
    las series de SAR (fact_telemetria_so, fuente='sar') IN PLACE sobre
    la misma estructura `series_por_nodo` que ya consume
    dashboard-ui/src/charts.ts::renderSerieMultiNodo() -- mismo mecanismo
    de chart, cero codigo TypeScript nuevo. Los nodos de SAR pueden no
    coincidir con `node_list` (hostnames de OCLUMON), asi que se expone
    una lista aparte `nodos_sar` -- el template pasa esa lista explicita
    en el spec del chart en vez de depender del default (node_list de
    OCLUMON) que ya usa main.ts para los charts multi-nodo sin `nodos`.
    Nunca lanza: una consulta vacia (sin archivos SAR en el caso) deja
    `nodos_sar` en lista vacia, el template ya sabe mostrar el estado
    vacio."""
    try:
        filas = con.execute(
            "SELECT nodo, metrica_o_error, timestamp, valor FROM fact_telemetria_so "
            "WHERE fuente = 'sar' AND valor IS NOT NULL ORDER BY nodo, metrica_o_error, timestamp"
        ).fetchall()
    except Exception:
        filas = []

    por_nodo_metrica = {}
    for nodo, metrica, ts, valor in filas:
        por_nodo_metrica.setdefault((nodo, metrica), []).append((ts, valor))

    nodos_vistos = set()
    series_por_nodo = resultado_episodios.setdefault("series_por_nodo", {})
    _MAPA_CLAVE = {
        "MEM_USED_PCT": "sar_mem_used_pct",
        "SWAP_USED_PCT": "sar_swap_used_pct",
        "MEM_FREE_KB": "sar_mem_free_kb",
    }
    for (nodo, metrica), pares in por_nodo_metrica.items():
        clave = _MAPA_CLAVE.get(metrica)
        if clave is None or nodo is None:
            continue
        nodos_vistos.add(nodo)
        series_por_nodo.setdefault(nodo, {})[clave] = _serie_puntos(pares)

    resultado_episodios["nodos_sar"] = sorted(nodos_vistos)


def _serie_puntos(filas):
    """[(timestamp, valor), ...] -> [{"t": epoch_seg, "v": valor}, ...],
    ordenado por tiempo, saltando filas con timestamp invalido o valor
    None (un hueco en el grafico es mas honesto que inventar un cero)."""
    puntos = []
    for ts, valor in filas:
        if ts is None or valor is None:
            continue
        try:
            t = _epoch_seg(ts)
        except Exception:
            continue
        puntos.append({"t": t, "v": valor})
    puntos.sort(key=lambda p: p["t"])
    return puntos


def construir_payload(db_path: str, veredicto_ia: dict, carpeta_caso: str,
                       resultado_episodios: dict = None) -> dict:
    """Abre su PROPIA conexion de solo lectura al .duckdb (separada y
    posterior a la de ForensicStorage/RootCauseEngine, que ya se cerraron
    para cuando se llega aca -- ver orden de llamadas en main()) y arma
    el payload que consume templates/dashboard.html: la serie de CPU
    (AWR) para uPlot, la tabla completa de eventos para Tabulator (con un
    tope defensivo, ver LIMITE_EVENTOS_TABLA), y un resumen.
    Nunca lanza -- cada seccion que falla queda vacia/con su aviso en vez
    de tumbar el resto del payload.

    resultado_episodios: salida de ejecutar_motor_episodios() -- episodios
    + linea de tiempo + rankings de procesos + series por nodo,
    calculados DIRECTO sobre los archivos oclumon crudos del caso (no via
    SQL). Se adjunta tal cual bajo la clave 'motor_episodios' del
    payload. Si se omite (None), queda una estructura vacia con la misma
    forma -- la plantilla del dashboard debe poder renderizar igual (sin
    esos paneles) en vez de romper."""
    errores = []
    con = None
    try:
        con = duckdb.connect(db_path, read_only=True)
    except Exception as e:
        errores.append(f"apertura de {db_path} para el dashboard: {e}")

    def query(sql, params=None, etiqueta=""):
        if con is None:
            return []
        try:
            return con.execute(sql, params or []).fetchall()
        except Exception as e:
            errores.append(f"query '{etiqueta}': {e}")
            return []

    series_cpu = _serie_puntos(query(
        """
        SELECT coalesce(begin_ts, end_ts), db_cpu_per_sec FROM fact_awr_snapshots
        WHERE db_cpu_per_sec IS NOT NULL
        ORDER BY 1
        """,
        etiqueta="series_cpu",
    ))
    # AAS (Average Active Sessions, metodologia oficial de Oracle) --
    # columna GENERATED de fact_awr_snapshots (ver core/storage.py), un
    # punto por snapshot AWR cargado. Hito "rediseno AWR" (2026-10-02).
    series_aas = _serie_puntos(query(
        "SELECT coalesce(begin_ts, end_ts), aas FROM fact_awr_snapshots "
        "WHERE aas IS NOT NULL ORDER BY 1",
        etiqueta="series_aas",
    ))
    # *** HITO "rediseno AWR + tabs + LogRouter acotado" (2026-10-02) ***
    # Panel Mike Dietrich (Grafico 3.1, auditoria externa): Parses/sec vs
    # Executes/sec, un punto por snapshot AWR -- mismo contrato que
    # series_cpu/series_aas arriba.
    series_parses = _serie_puntos(query(
        "SELECT coalesce(begin_ts, end_ts), parses_per_sec FROM fact_awr_snapshots "
        "WHERE parses_per_sec IS NOT NULL ORDER BY 1",
        etiqueta="series_parses",
    ))
    series_executes = _serie_puntos(query(
        "SELECT coalesce(begin_ts, end_ts), executes_per_sec FROM fact_awr_snapshots "
        "WHERE executes_per_sec IS NOT NULL ORDER BY 1",
        etiqueta="series_executes",
    ))

    # Panel Tom Kyte (Grafico 1.1, auditoria externa): el DB Time
    # desglosado por categoria, apilado por snapshot AWR -- "DE AWR NADA
    # MAS GRAFICAS EL AAS?" fue la critica textual del usuario; una linea
    # aislada de AAS no explica el "por que", esto si. "DB CPU" ya viene
    # como fila de fact_awr_wait_events (pseudo wait-event que AWR imprime
    # junto a los wait events reales, confirmado contra los AWR reales del
    # caso) -- sin esa fila, el resto de la tabla (User I/O/Cluster/
    # Concurrency/Application) no suma el 100% del DB Time, solo la parte
    # de espera. Agregacion 100% SQL, nunca se suma a mano en Python ni en
    # el frontend.
    filas_dbtime = query(
        """
        SELECT
            w.snapshot_id, s.host, s.begin_ts, s.end_ts,
            CASE
                WHEN w.evento = 'DB CPU' THEN 'DB CPU'
                WHEN w.wait_class = 'User I/O' THEN 'User I/O'
                WHEN w.wait_class = 'Cluster' THEN 'Cluster'
                WHEN w.wait_class IN ('Concurrency', 'Application') THEN 'Concurrency + Application'
                ELSE 'Otros'
            END AS categoria,
            sum(w.tiempo_s) AS segundos
        FROM fact_awr_wait_events w
        JOIN fact_awr_snapshots s ON s.snapshot_id = w.snapshot_id
        WHERE w.tiempo_s IS NOT NULL
        GROUP BY w.snapshot_id, s.host, s.begin_ts, s.end_ts, categoria
        ORDER BY coalesce(s.begin_ts, s.end_ts), categoria
        """,
        etiqueta="awr_dbtime_breakdown",
    )
    awr_dbtime_breakdown = []
    for sid, host, begin_ts, end_ts, categoria, segundos in filas_dbtime:
        ref = begin_ts or end_ts
        # etiqueta de categoria X del chart apilado: host + fecha/hora
        # explicita (nunca solo la hora -- esa es exactamente la falla de
        # trazabilidad senalada en la auditoria externa, sec. 1/3).
        etiqueta = f"{host or '?'} {ref.strftime('%d/%m %H:%M')}" if ref else (host or f"snap {sid}")
        awr_dbtime_breakdown.append({"etiqueta": etiqueta, "categoria": categoria, "segundos": segundos})

    # Cabecera de infraestructura (Hito "rediseno AWR", 2026-10-02): hosts +
    # identidad de instancia, ahora que el modelo dimensional los tiene
    # tipados (dim_infraestructura/dim_database) -- antes solo vivian en el
    # dict de metadata del parser, sin llegar nunca al dashboard. max() por
    # host porque puede haber mas de un snapshot AWR del mismo host -- los
    # valores de hardware/identidad no cambian entre snapshots del mismo
    # caso, max() es solo para colapsar a 1 fila por host sin inventar nada.
    filas_infra = query(
        """
        SELECT i.host, max(i.cores), max(i.sockets), max(i.mem_gb), max(i.num_cpus),
               max(d.db_name), max(d.instance_name), max(d.release), max(d.rac)
        FROM dim_infraestructura i
        LEFT JOIN dim_database d ON d.host = i.host AND d.caso_id = i.caso_id
        GROUP BY i.host ORDER BY i.host
        """,
        etiqueta="infraestructura",
    )
    infraestructura = [
        {
            "host": host, "cores": cores, "sockets": sockets, "mem_gb": mem_gb,
            "num_cpus": num_cpus, "db_name": db_name, "instance_name": instance_name,
            "release": release, "rac": rac,
        }
        for host, cores, sockets, mem_gb, num_cpus, db_name, instance_name, release, rac in filas_infra
    ]

    # Top Wait Events por snapshot, coloreados por Wait Class (Hito
    # "rediseno AWR", 2026-10-02) -- reemplaza el viejo panel de gipcd
    # (fuente retirada, ver Hito de simplificacion). Se renderiza 100% en
    # Jinja2 (como "Tabla cruda"/"Evidencias") -- es contenido estatico por
    # caso, no necesita un chart ni JavaScript nuevo. "Cluster" (Global
    # Cache / interconnect de RAC) es una Wait Class real de Oracle, no una
    # categoria propia de este pipeline -- queda visible en la columna de
    # Wait Class de cada evento, sin necesitar un panel aparte.
    filas_snap = query(
        """
        SELECT snapshot_id, host, awr_file, begin_ts, end_ts, elapsed_seg,
               db_cpu_per_sec, db_time_per_sec, aas
        FROM fact_awr_snapshots ORDER BY coalesce(begin_ts, end_ts)
        """,
        etiqueta="awr_snapshots",
    )
    filas_wait = query(
        """
        SELECT snapshot_id, evento, wait_class, waits, tiempo_s, pct_dbtime, avg_wait_ms
        FROM fact_awr_wait_events ORDER BY snapshot_id, pct_dbtime DESC NULLS LAST
        """,
        etiqueta="awr_wait_events",
    )
    wait_por_snapshot = {}
    for sid, evento, wait_class, waits, tiempo_s, pct_dbtime, avg_wait_ms in filas_wait:
        wait_por_snapshot.setdefault(sid, []).append({
            "evento": evento, "wait_class": wait_class, "waits": waits,
            "tiempo_s": tiempo_s, "pct_dbtime": pct_dbtime, "avg_wait_ms": avg_wait_ms,
        })
    awr = {
        "snapshots": [
            {
                "snapshot_id": sid, "host": host, "awr_file": awr_file,
                "begin_ts": begin_ts.isoformat() if begin_ts is not None else None,
                "end_ts": end_ts.isoformat() if end_ts is not None else None,
                "elapsed_seg": elapsed_seg, "db_cpu_per_sec": db_cpu_per_sec,
                "db_time_per_sec": db_time_per_sec, "aas": aas,
                "wait_events": wait_por_snapshot.get(sid, []),
            }
            for sid, host, awr_file, begin_ts, end_ts, elapsed_seg, db_cpu_per_sec, db_time_per_sec, aas
            in filas_snap
        ],
    }

    eventos_unificados_sql = _sql_eventos_unificados()

    total_eventos = 0
    fuentes = {}
    rango = (None, None)
    filas_resumen = query(
        f"SELECT fuente, count(*) FROM ({eventos_unificados_sql}) u GROUP BY fuente",
        etiqueta="resumen_fuentes",
    )
    if filas_resumen:
        fuentes = {f: n for f, n in filas_resumen}
        total_eventos = sum(fuentes.values())
    filas_rango = query(
        f"SELECT min(timestamp), max(timestamp) FROM ({eventos_unificados_sql}) u",
        etiqueta="resumen_rango",
    )
    if filas_rango and filas_rango[0][0] is not None:
        desde, hasta = filas_rango[0]
        rango = (desde.isoformat(), hasta.isoformat())

    eventos_rows = query(
        f"""
        SELECT timestamp, nodo, fuente, metrica_o_error, valor, detalles
        FROM ({eventos_unificados_sql}) u ORDER BY timestamp
        LIMIT ?
        """,
        [LIMITE_EVENTOS_TABLA + 1],
        etiqueta="eventos_tabla",
    )
    truncada = len(eventos_rows) > LIMITE_EVENTOS_TABLA
    eventos_rows = eventos_rows[:LIMITE_EVENTOS_TABLA]
    eventos = [{
        "timestamp": ts.isoformat() if ts is not None else None,
        "nodo": nodo, "fuente": fuente, "metrica_o_error": metrica,
        "valor": valor, "detalles": detalles,
    } for ts, nodo, fuente, metrica, valor, detalles in eventos_rows]

    # Cobertura real por fuente+nodo -- alimenta core/dashboard_engine.py
    # para la pregunta literal del usuario ("si es oclumon graficamos y
    # si es sar tambien y si es awr tambien"): que fuentes tecnicas
    # tienen AL MENOS 1 fila real para cada nodo puntual, no solo para
    # el caso en general.
    cobertura_rows = query(
        f"SELECT DISTINCT fuente, nodo FROM ({eventos_unificados_sql}) u WHERE nodo IS NOT NULL",
        etiqueta="cobertura_por_fuente",
    )
    cobertura_por_fuente = {}
    for fuente, nodo in cobertura_rows:
        cobertura_por_fuente.setdefault(fuente, set()).add(nodo)

    if resultado_episodios is None:
        resultado_episodios = {
            "node_list": [], "nic_types": [], "episodios": [], "eventos_discretos": [],
            "linea_tiempo": [], "proc_rankings": {}, "oclumon_diagnostics": [],
            "series_por_nodo": {}, "series_max": {}, "device_names": [],
            "device_names_vistos_total": 0, "filesystem_mounts": [],
        }
    # Series de SAR (Hito "Sistema Operativo (SAR)", 2026-10-02) -- se
    # inyectan ANTES de cerrar `con` (las lee directo de fact_telemetria_so)
    # y ANTES de construir_informe() (que ya calcula series_relevantes
    # sobre series_por_nodo, asi que debe ver las claves sar_* tambien).
    if con is not None:
        _inyectar_series_sar(con, resultado_episodios)
        con.close()
    else:
        resultado_episodios.setdefault("nodos_sar", [])

    # Motor de activacion de componentes por episodio (core/dashboard_engine.py)
    # -- el catalogo versionado de componentes (core/component_catalog.py)
    # resuelto contra ESTE caso puntual: que episodios disparan que
    # componente, que paneles opcionales tienen cobertura real de datos,
    # y los 3 bloques Hechos/Diagnostico/Presentacion que arma
    # templates/dashboard.html (Jinja2, ver core/html_builder.py). Nunca
    # lanza -- ver construir_informe().
    informe = construir_informe(
        resultado_episodios=resultado_episodios,
        estado_salud=veredicto_ia.get("estado_salud"),
        cobertura_por_fuente=cobertura_por_fuente,
    )

    return {
        "generado_en": datetime.now().isoformat(timespec="seconds"),
        "caso": os.path.basename(os.path.normpath(carpeta_caso)) or carpeta_caso,
        "motor_episodios": resultado_episodios,
        "informe": informe,
        "veredicto": {
            # Ya no hay 'texto'/'literatura_experta' automaticos (ver
            # aviso de alcance arriba) -- veredicto_ia aca solo trae el
            # contexto rapido de calcular_contexto_caso(): hechos SQL +
            # estado de salud. El chat a pedido (modo --servir) usa
            # 'hechos_telemetria'/'estado_salud' tal cual para
            # responder_pregunta().
            "hechos_telemetria": veredicto_ia.get("hechos_telemetria"),
            "estado_salud": veredicto_ia.get("estado_salud"),
        },
        "resumen": {
            "total_eventos": total_eventos,
            "fuentes": fuentes,
            "rango_tiempo": list(rango),
            "tabla_truncada": truncada,
            "limite_tabla": LIMITE_EVENTOS_TABLA,
        },
        "series_cpu": series_cpu,
        "series_aas": series_aas,
        "series_parses": series_parses,
        "series_executes": series_executes,
        "awr_dbtime_breakdown": awr_dbtime_breakdown,
        "infraestructura": infraestructura,
        "awr": awr,
        "eventos": eventos,
        "errores_payload": errores,
    }


def generar_reporte_html(db_path: str, veredicto_ia: dict, carpeta_caso: str,
                          ruta_template: str = None, resultado_episodios: dict = None) -> str:
    """Arma el payload (ver construir_payload) y lo renderiza con Jinja2
    real (core/html_builder.py, Hito "Oracle Diagnostic Lab" 2026-10-01 --
    reemplaza el `html.replace("__PAYLOAD_JSON__", ...)` de texto plano
    que usaba esta funcion desde el Hito 6). Escribe `informe_incidente.html`
    dentro de la carpeta del caso y devuelve la ruta completa. Usa
    os.path.join en todo momento (nunca concatena con '/') para que las
    rutas se resuelvan bien tanto en Windows como en Linux/Mac.

    'ruta_template' queda como parametro por compatibilidad con llamadores
    existentes pero ya NO se usa -- core/html_builder.py resuelve sus
    propias plantillas (templates/base.html + templates/dashboard.html)
    de forma fija, igual que antes resolvia NOMBRE_TEMPLATE_DASHBOARD."""
    payload = construir_payload(db_path, veredicto_ia, carpeta_caso, resultado_episodios)
    html = render_dashboard(payload)

    ruta_salida = os.path.join(carpeta_caso, NOMBRE_INFORME_SALIDA)
    with open(ruta_salida, "w", encoding="utf-8") as f:
        f.write(html)

    log.info("generar_reporte_html: informe escrito en %s (%d eventos, %d error(es) en el payload)",
              ruta_salida, len(payload["eventos"]), len(payload["errores_payload"]))
    return ruta_salida


def ejecutar_caso_completo(carpeta: str, db_path: str, log_cb=print) -> dict:
    """Orquestacion de punta a punta: ingiere la carpeta, calcula el
    contexto rapido de IA (SOLO SQL, ver ai/engine.py) y escribe el
    dashboard. Devuelve un dict con las rutas/resultados clave. Cada fase
    tiene su propia red de seguridad (ingerir_carpeta ya nunca lanza por
    archivo individual; RootCauseEngine nunca lanza; generar_reporte_html
    puede lanzar si el template no existe o esta corrupto -- eso SI se
    deja propagar, porque sin dashboard no hay nada que mostrarle al
    usuario).

    Desde el Hito de simplificacion de alcance (2026-10-01, "agilizar el
    pipeline"), la llamada a Ollama (el cuello de botella real, ~230s
    medidos) YA NO corre aca -- solo el contexto SQL rapido. La consulta
    libre a Ollama queda a pedido, ver main()/--servir."""
    if not os.path.isdir(carpeta):
        raise NotADirectoryError(f"No es una carpeta: {carpeta}")

    log_cb(f"== Evaluando caso: {carpeta} ==")
    t_ingesta_inicio = time.monotonic()
    resumen_ingesta = ingerir_carpeta(carpeta, db_path, log_cb=log_cb)
    t_ingesta = time.monotonic() - t_ingesta_inicio

    log_cb("")
    log_cb("== Calculando contexto de IA (SOLO SQL, sin Ollama) ==")
    t_ia_inicio = time.monotonic()
    try:
        with RootCauseEngine(db_path=db_path) as engine:
            resultado_ia = engine.calcular_contexto_caso()
        estado = (resultado_ia.get("estado_salud") or {}).get("estado", "N/D")
        log_cb(f"Estado de salud calculado: {estado}")
    except Exception as e:
        # RootCauseEngine ya maneja sus propios errores internamente --
        # esto solo cubre un fallo todavia mas basico (p.ej. no se pudo
        # ni instanciar el motor).
        log_cb(f"ERROR inesperado inicializando el motor de IA: {e}")
        resultado_ia = {
            "hechos_telemetria": "",
            "estado_salud": {"estado": "N/D", "motivos": [f"error al calcular: {e}"]},
            "errors": [str(e)],
        }
    t_ia = time.monotonic() - t_ia_inicio
    log_cb(f"(contexto de IA: {t_ia:.2f}s)")

    log_cb("")
    log_cb("== Motor de episodios (deteccion de anomalias oclumon) ==")
    t_episodios_inicio = time.monotonic()
    rutas_por_tipo = resumen_ingesta.get("rutas_por_tipo", {})
    resultado_episodios = ejecutar_motor_episodios(
        oclumon_paths=rutas_por_tipo.get("oclumon", []),
        log_cb=log_cb,
    )
    t_episodios = time.monotonic() - t_episodios_inicio
    log_cb(f"(motor de episodios: {t_episodios:.2f}s -- "
           f"{len(resultado_episodios['episodios'])} episodio(s), "
           f"{len(resultado_episodios['linea_tiempo'])} item(s) en la linea de tiempo)")

    log_cb("")
    log_cb("== Generando dashboard HTML ==")
    t_dashboard_inicio = time.monotonic()
    ruta_informe = generar_reporte_html(db_path, resultado_ia, carpeta,
                                         resultado_episodios=resultado_episodios)
    t_dashboard = time.monotonic() - t_dashboard_inicio
    log_cb(f"Informe generado: {ruta_informe} ({t_dashboard:.2f}s)")

    # Resumen de tiempos por fase -- pedido explicito del usuario ("la
    # performance se demora 5 minutos"), para que cada corrida diga
    # EXACTAMENTE donde se va el tiempo en vez de dejarlo adivinar. Desde
    # que la IA dejo de correr automaticamente, t_ia deberia quedar
    # chico (solo SQL) -- si no es asi, es la primera cosa a revisar.
    t_total_fases = t_ingesta + t_ia + t_episodios + t_dashboard
    log_cb("")
    log_cb("== Resumen de tiempos ==")
    log_cb(f"  Ingesta (clasificar+parsear+insertar): {t_ingesta:.2f}s")
    log_cb(f"  Contexto de IA (SOLO SQL):               {t_ia:.2f}s")
    log_cb(f"  Motor de episodios:                     {t_episodios:.2f}s")
    log_cb(f"  Generacion del dashboard HTML:          {t_dashboard:.2f}s")
    log_cb(f"  TOTAL:                                  {t_total_fases:.2f}s")

    return {
        "resumen_ingesta": resumen_ingesta,
        "veredicto_ia": resultado_ia,
        "resultado_episodios": resultado_episodios,
        "ruta_informe": ruta_informe,
        "tiempos_fases": {
            "ingesta_seg": round(t_ingesta, 3),
            "ia_seg": round(t_ia, 3),
            "episodios_seg": round(t_episodios, 3),
            "dashboard_seg": round(t_dashboard, 3),
            "total_seg": round(t_total_fases, 3),
        },
    }


# ---------------------------------------------------------------------
# Modo --servir: servidor HTTP local (stdlib, sin dependencias nuevas)
# que sirve la carpeta del caso (incluyendo informe_incidente.html) y
# expone /api/preguntar para el chat con Ollama -- decision explicita
# del usuario de NO depender de que un fetch() desde un HTML abierto por
# file:// pueda pasar el CORS de Ollama (ver claude/rac_forensic_lab.md
# para el analisis completo de esa ambiguedad). Al servir por
# http://localhost, el navegador llama a ESTE servidor (mismo origen),
# que a su vez llama a Ollama server-side -- eso nunca pasa por CORS de
# navegador, sea lo que sea que Ollama permita o no.
# ---------------------------------------------------------------------

def _servir_dashboard(carpeta: str, db_path: str, contexto_ia: dict, puerto: int, log_cb=print):
    """Levanta un http.server.ThreadingHTTPServer rooted en `carpeta`
    (sirve informe_incidente.html y sus assets tal cual) + un endpoint
    POST /api/preguntar que hace de proxy server-side a Ollama via
    RootCauseEngine.responder_pregunta(), usando el contexto YA
    CALCULADO (contexto_ia) -- nunca vuelve a correr SQL por pregunta.
    Bloqueante: corre hasta Ctrl+C."""
    import json as _json
    from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
    from functools import partial

    hechos = contexto_ia.get("hechos_telemetria", "")
    estado_salud = contexto_ia.get("estado_salud") or {"estado": "N/D", "motivos": []}

    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, fmt, *args):
            log_cb(f"[servir] {self.address_string()} {fmt % args}")

        def do_POST(self):
            if self.path != "/api/preguntar":
                self.send_error(404, "No existe este endpoint")
                return
            try:
                largo = int(self.headers.get("Content-Length", "0"))
                crudo = self.rfile.read(largo) if largo > 0 else b"{}"
                cuerpo = _json.loads(crudo.decode("utf-8") or "{}")
                pregunta = (cuerpo.get("pregunta") or "").strip()
            except Exception as e:
                self._responder_json({"error": f"cuerpo invalido: {e}"}, status=400)
                return

            log_cb(f"[servir] pregunta recibida ({len(pregunta)} caracteres) -- consultando Ollama...")
            try:
                with RootCauseEngine(db_path=db_path) as engine:
                    respuesta = engine.responder_pregunta(pregunta, hechos, estado_salud)
            except Exception as e:
                respuesta = f"[AVISO] error inesperado consultando la IA: {e}"
            self._responder_json({"respuesta": respuesta})

        def _responder_json(self, data: dict, status: int = 200):
            cuerpo = _json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(cuerpo)))
            self.end_headers()
            self.wfile.write(cuerpo)

    HandlerConCarpeta = partial(Handler, directory=carpeta)
    servidor = ThreadingHTTPServer(("127.0.0.1", puerto), HandlerConCarpeta)
    log_cb("")
    log_cb(f"== Modo --servir activo: http://localhost:{puerto}/{NOMBRE_INFORME_SALIDA} ==")
    log_cb("   (el panel de IA del dashboard consulta este servidor -- Ctrl+C para detener)")
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        log_cb("\n[servir] detenido por el usuario.")
    finally:
        servidor.server_close()


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")

    ap = argparse.ArgumentParser(
        description="RAC Forensic Lab -- clasifica evidencia de un caso (oclumon/sar/awr), la "
                    "vuelca en DuckDB y escribe el dashboard HTML del incidente")
    ap.add_argument("carpeta", help="Carpeta del caso (se recorre recursivamente)")
    ap.add_argument("--db", default="caso_analisis.duckdb", help="Ruta del .duckdb de salida")
    ap.add_argument("--servir", nargs="?", const=8787, type=int, metavar="PUERTO", default=None,
                     help="Despues de generar el informe, levanta un servidor HTTP local "
                          "(puerto por defecto 8787) para habilitar el panel de consulta a la "
                          "IA (Ollama) del dashboard -- sin esto el panel queda inactivo.")
    args = ap.parse_args()

    if not os.path.isdir(args.carpeta):
        print(f"No es una carpeta: {args.carpeta}", file=sys.stderr)
        sys.exit(1)

    print()  # separa el log de nivel INFO del resto de la salida
    resultado = ejecutar_caso_completo(args.carpeta, args.db, log_cb=print)
    print(f"\nListo. Dashboard: {resultado['ruta_informe']}")

    if args.servir is not None:
        _servir_dashboard(args.carpeta, args.db, resultado["veredicto_ia"], args.servir, log_cb=print)


if __name__ == "__main__":
    main()
