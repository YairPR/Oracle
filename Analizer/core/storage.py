"""
core/storage.py

Capa de almacenamiento forense analitico (Hito 2 del RAC Forensic Lab).

ForensicStorage es un wrapper delgado sobre una base de datos DuckDB
embebida (un solo archivo .duckdb, sin servidor) que centraliza TODOS los
eventos de TODAS las fuentes (oclumon, sar, alert, awr, trace, ...) para
poder cruzarlas con SQL en vez de cruzar listas de Python a mano (lo que
ya hace build_timeline() en el analizador de campo, pero ahi es un merge
de solo 2 fuentes escrito a mano; aqui el motivo de DuckDB es poder
escalar ese mismo cruce a N fuentes con SQL en vez de reescribir el merge
cada vez que se suma una fuente nueva).

Nota de alcance deliberada: el analizador de campo (oclumon_analyzer.py,
en dept300/) se mantiene con CERO dependencias externas a proposito,
porque corre directo en una laptop corporativa sin permisos de
administrador. rac-lab/ es un workbench analitico aparte, con su propio
venv -- aqui SI se asume una dependencia real (duckdb) porque el venv ya
aisla la instalacion del Python del sistema y el motor columnar
vectorizado de DuckDB es la herramienta correcta para correlacionar
series de tiempo + eventos discretos de multiples fuentes con SQL.

Migracion a modelo dimensional (2026-10-02, post-auditoria -- ver
AUDIT_ANTI.txt y claude/analisis_tecnico_pipeline.md): la version anterior
de este modulo volcaba TODO en una sola tabla plana (`eventos_forenses`)
con una columna generica `metrica_o_error` reutilizada por convencion de
string para absolutamente todo (una metrica de oclumon, un ORA-/CRS-, un
nombre de wait event de AWR...). Eso funcionaba para correlacion simple
por eje de tiempo, pero es un anti-patron en cuanto se quiere razonar
sobre la ESTRUCTURA de los datos: AAS (Average Active Sessions) real de
AWR, metricas de Global Cache, comparar lineas de tiempo entre un
incidente y un baseline, o indexar contenido para una futura capa de RAG.
Esas necesidades piden tablas con columnas propias y tipadas, no una
clave libre. Esta version reemplaza `eventos_forenses` por un esquema de
8 tablas dimensionales:

  - dim_caso             : 1 fila por caso analizado.
  - dim_infraestructura  : snapshot de hardware/OS por host (de oclumon/sar).
  - dim_database         : identidad de instancia/release por host (de AWR).
  - fact_telemetria_so   : la telemetria de oclumon/sar/alert/trace que
                            antes vivia en eventos_forenses (mismo rol,
                            mismas columnas, ahora con caso_id).
  - fact_awr_snapshots   : un snapshot AWR = una fila, con AAS calculado
                            automaticamente por DuckDB (columna GENERATED).
  - fact_awr_wait_events : wait events de un snapshot AWR, con el tiempo
                            medio de espera calculado automaticamente.
  - fact_timeline        : preparada para comparar lineas de tiempo entre
                            incidentes/baseline (Hito futuro) -- DDL
                            presente, CERO filas esperadas en este hito,
                            no es un bug.
  - kb_vectores          : preparada para una futura capa de RAG via
                            embeddings (Hito futuro) -- mismo caso: DDL
                            presente, CERO filas esperadas en este hito.

El contrato de nombres de tabla/columna de este archivo es FIJO: lo
consume `ai/engine.py`, que se migra en un proceso aparte para dejar de
consultar `eventos_forenses` (hoy eliminada) y empezar a consultar estas
8 tablas directamente con SQL.

Columnas generadas (`aas`, `avg_wait_ms`): se verifico empiricamente
contra DuckDB 1.5.6 (la version instalada en este venv) que la sintaxis
estandar `GENERATED ALWAYS AS (<expr>) VIRTUAL` funciona tal cual select
de la documentacion de DuckDB -- no hizo falta ningun workaround. Por eso
`insertar_awr_snapshot()` y `bulk_insert_wait_events()` nunca escriben
`aas`/`avg_wait_ms` explicitamente: DuckDB las calcula solas a partir de
las columnas base en cada SELECT, y quedan siempre consistentes con
`elapsed_seg`/`db_time_seg`/`waits`/`tiempo_s` sin que este modulo tenga
que duplicar la formula en Python.

UPSERT de `dim_caso` (`registrar_caso`): se verifico empiricamente que
esta version de DuckDB soporta `INSERT ... ON CONFLICT (col) DO UPDATE
SET ...` de forma nativa (sintaxis estilo PostgreSQL), asi que
`registrar_caso()` lo usa directo -- no hizo falta el patron alternativo
de DELETE+INSERT.

IDs en memoria (`_next_infra_id`, `_next_db_id`, `_next_snapshot_id`,
`_next_event_id`): deliberadamente NO son una `SEQUENCE` de DuckDB.
Cada corrida de `ingerir_carpeta()` (ver analizador.py) reprocesa el caso
completo desde una base vacia (ver `_limpiar_datos_previos()` mas abajo),
asi que no hace falta que los IDs persistan entre corridas -- un simple
contador en memoria que arranca en 1 y se resetea en cada limpieza es
correcto y mas simple que coordinar una SEQUENCE de DuckDB con ese mismo
reseteo.

Idempotencia (heredada de la version anterior, post-auditoria 2026-10-01):
antes del fix original, `ForensicStorage` solo garantizaba que la tabla
EXISTIERA (CREATE TABLE IF NOT EXISTS), nunca que estuviera VACIA al
empezar una ingesta nueva. Como `ingerir_carpeta()` siempre reprocesa la
carpeta del caso COMPLETA en cada corrida (no hay ingesta incremental en
este proyecto, cada corrida es "la foto completa de este caso, ahora"),
correr el analisis una segunda vez sobre la misma carpeta y el mismo
.duckdb duplicaba silenciosamente cada evento. Ese mismo principio aplica
ahora a las 8 tablas: por defecto, `ForensicStorage` las vacia TODAS al
conectarse (ver `limpiar_al_conectar` / `_limpiar_datos_previos()`) --
nunca en silencio: si habia filas, se loguea cuanto se elimino y por que.
Si alguna vez hace falta una ingesta incremental de verdad (acumular
datos de varias corridas en una misma base), `limpiar_al_conectar=False`
esta disponible, pero el default seguro es limpiar, porque eso es lo que
el resto del pipeline ya asume.

Sobre bulk_insert_telemetria()/bulk_insert_wait_events() -- como cargar
list[dict] en DuckDB rapido sin sumar pandas/pyarrow encima de duckdb
(mas dependencias en un lab que ya decidio sumar una no es gratis
tampoco): se probaron 3 formas con datos reales antes de elegir:
  1. con.executemany(INSERT..., filas) linea por linea -> con 5000 filas
     tardo ~2.8s (~1800 filas/s) incluso con una transaccion explicita
     alrededor, y con 100000 filas sin esa transaccion ni siquiera
     termino en 2 minutos (autocommit por fila de por medio). Descartada.
  2. con.append(tabla, df) -- existe en la API de Python de DuckDB, pero
     pide un pandas.DataFrame. Habria que sumar pandas solo para esto.
     Descartada (y ademas DuckDB en esta version no expone un objeto
     Appender nativo en Python, solo este .append() basado en DataFrame).
  3. Un solo INSERT con multiples tuplas VALUES (?,?,?,?,?,?) por lote,
     envuelto en una transaccion explicita -- en la misma prueba,
     100000 filas en ~8-12s (8000-12000 filas/s), sin sumar NINGUNA
     dependencia ademas de duckdb. Es la que implementan estos metodos.
Para los volumenes reales de un caso (cientos a pocas decenas de miles de
eventos por fuente) esto sobra; si algun dia hace falta cargar millones de
filas (p.ej. sar a resolucion de 10s durante semanas) vale la pena
reevaluar sumar pyarrow para un camino mas vectorizado.
"""

import logging
from datetime import datetime

import duckdb

log = logging.getLogger("rac_forensic_lab.storage")

# ---------------------------------------------------------------------------
# DDL -- esquema dimensional (8 tablas). Contrato FIJO: estos nombres de
# tabla y columna los consume ai/engine.py (migrado en un proceso aparte).
# ---------------------------------------------------------------------------

DDL_DIM_CASO = """
CREATE TABLE IF NOT EXISTS dim_caso (
    caso_id      VARCHAR PRIMARY KEY,
    nombre       VARCHAR,
    creado_en    TIMESTAMP
)
"""

DDL_DIM_INFRAESTRUCTURA = """
CREATE TABLE IF NOT EXISTS dim_infraestructura (
    infra_id       INTEGER PRIMARY KEY,
    caso_id        VARCHAR,
    host           VARCHAR,
    cpus           DOUBLE,
    cores          DOUBLE,
    sockets        DOUBLE,
    mem_gb         DOUBLE,
    kernel         VARCHAR,
    num_cpus       DOUBLE,
    busy_time      DOUBLE,
    idle_time      DOUBLE,
    iowait_time    DOUBLE,
    actualizado_en TIMESTAMP
)
"""

DDL_DIM_DATABASE = """
CREATE TABLE IF NOT EXISTS dim_database (
    db_id          INTEGER PRIMARY KEY,
    caso_id        VARCHAR,
    host           VARCHAR,
    db_name        VARCHAR,
    instance_name  VARCHAR,
    release        VARCHAR,
    rac            VARCHAR,
    actualizado_en TIMESTAMP
)
"""

# fact_telemetria_so reemplaza a la antigua eventos_forenses: mismo rol
# (telemetria cruda de oclumon/sar/alert/trace sobre un eje de tiempo
# comun), ahora con caso_id para poder tener mas de un caso en la misma
# base sin mezclar sus eventos.
DDL_FACT_TELEMETRIA_SO = """
CREATE TABLE IF NOT EXISTS fact_telemetria_so (
    caso_id          VARCHAR,
    timestamp        TIMESTAMP,
    nodo             VARCHAR,
    fuente           VARCHAR,
    metrica_o_error  VARCHAR,
    valor            DOUBLE,
    detalles         TEXT
)
"""

# aas (Average Active Sessions) es columna GENERATED: DuckDB la calcula
# sola en cada SELECT a partir de db_time_seg/elapsed_seg, nunca se
# inserta a mano (ver nota de columnas generadas en el docstring del
# modulo) -- asi queda garantizado que nunca se desincroniza de sus
# columnas base.
DDL_FACT_AWR_SNAPSHOTS = """
CREATE TABLE IF NOT EXISTS fact_awr_snapshots (
    snapshot_id              INTEGER PRIMARY KEY,
    caso_id                  VARCHAR,
    host                     VARCHAR,
    awr_file                 VARCHAR,
    begin_snap_id            VARCHAR,
    end_snap_id              VARCHAR,
    begin_ts                 TIMESTAMP,
    end_ts                   TIMESTAMP,
    elapsed_seg              DOUBLE,
    db_cpu_per_sec           DOUBLE,
    db_time_per_sec          DOUBLE,
    logical_reads_per_sec    DOUBLE,
    physical_reads_per_sec   DOUBLE,
    physical_writes_per_sec  DOUBLE,
    -- *** HITO "rediseno AWR + tabs + LogRouter acotado" (2026-10-02) ***
    -- Parses/Executes por segundo (panel Mike Dietrich, Grafico 3.1) --
    -- ya los extrae parsers/awr.py::parse_estructurado() desde este hito.
    parses_per_sec           DOUBLE,
    executes_per_sec         DOUBLE,
    num_cpus                 DOUBLE,
    busy_time                DOUBLE,
    idle_time                DOUBLE,
    iowait_time              DOUBLE,
    db_time_seg              DOUBLE,
    aas DOUBLE GENERATED ALWAYS AS (
        CASE WHEN elapsed_seg IS NOT NULL AND elapsed_seg > 0
             THEN db_time_seg / elapsed_seg END
    ) VIRTUAL
)
"""

# avg_wait_ms, igual que aas arriba: columna GENERATED, nunca se inserta
# a mano.
DDL_FACT_AWR_WAIT_EVENTS = """
CREATE TABLE IF NOT EXISTS fact_awr_wait_events (
    event_id      INTEGER PRIMARY KEY,
    caso_id       VARCHAR,
    snapshot_id   INTEGER,
    host          VARCHAR,
    evento        VARCHAR,
    wait_class    VARCHAR,
    waits         DOUBLE,
    tiempo_s      DOUBLE,
    pct_dbtime    DOUBLE,
    avg_wait_ms DOUBLE GENERATED ALWAYS AS (
        CASE WHEN waits IS NOT NULL AND waits > 0 AND tiempo_s IS NOT NULL
             THEN (tiempo_s * 1000.0) / waits END
    ) VIRTUAL
)
"""

# Sin ingestion en este hito -- preparada para un Hito futuro que compare
# lineas de tiempo entre incidentes y un baseline. DDL presente, CERO
# filas esperadas todavia: no es un bug, es a proposito.
DDL_FACT_TIMELINE = """
CREATE TABLE IF NOT EXISTS fact_timeline (
    timeline_id   INTEGER PRIMARY KEY,
    caso_id       VARCHAR,
    tag           VARCHAR,
    timestamp     TIMESTAMP,
    nodo          VARCHAR,
    descripcion   VARCHAR,
    severidad     VARCHAR
)
"""

# Sin ingestion en este hito -- preparada para una futura capa de RAG
# (busqueda semantica sobre el contenido del caso via embeddings). DDL
# presente, CERO filas esperadas todavia: no es un bug, es a proposito.
DDL_KB_VECTORES = """
CREATE TABLE IF NOT EXISTS kb_vectores (
    vector_id     INTEGER PRIMARY KEY,
    caso_id       VARCHAR,
    fuente        VARCHAR,
    contenido     TEXT,
    embedding     FLOAT[768]
)
"""

# Orden de creacion: sin FKs declaradas (DuckDB las valida pero no las
# necesitamos para la logica de esta clase), pero se mantiene el orden
# dimensiones-antes-que-hechos por claridad de lectura del DDL.
_DDL_TABLAS = [
    DDL_DIM_CASO,
    DDL_DIM_INFRAESTRUCTURA,
    DDL_DIM_DATABASE,
    DDL_FACT_TELEMETRIA_SO,
    DDL_FACT_AWR_SNAPSHOTS,
    DDL_FACT_AWR_WAIT_EVENTS,
    DDL_FACT_TIMELINE,
    DDL_KB_VECTORES,
]

# Nombres de las 8 tablas, en el mismo orden -- se reutiliza tanto para
# contar/vaciar en _limpiar_datos_previos() como para no tener que repetir
# la lista literal en mas de un lugar.
_TODAS_LAS_TABLAS = [
    "dim_caso",
    "dim_infraestructura",
    "dim_database",
    "fact_telemetria_so",
    "fact_awr_snapshots",
    "fact_awr_wait_events",
    "fact_timeline",
    "kb_vectores",
]

# Indices sobre las columnas por las que se va a filtrar/cruzar en casi
# cualquier consulta de correlacion (rango de tiempo, por nodo, por
# fuente, o el join hecho->dimension por caso_id/snapshot_id) -- DuckDB
# los usa para podar que bloques columnar escanear en vez de recorrer
# toda la tabla. Mismo criterio que la version anterior del archivo:
# se indexa lo que mas se filtra, no cada columna por reflejo.
DDL_INDICES = [
    "CREATE INDEX IF NOT EXISTS idx_telemetria_ts ON fact_telemetria_so(timestamp)",
    "CREATE INDEX IF NOT EXISTS idx_telemetria_nodo ON fact_telemetria_so(nodo)",
    "CREATE INDEX IF NOT EXISTS idx_telemetria_fuente ON fact_telemetria_so(fuente)",
    "CREATE INDEX IF NOT EXISTS idx_awr_snapshots_caso ON fact_awr_snapshots(caso_id)",
    "CREATE INDEX IF NOT EXISTS idx_awr_wait_events_snapshot ON fact_awr_wait_events(snapshot_id)",
    "CREATE INDEX IF NOT EXISTS idx_infraestructura_caso ON dim_infraestructura(caso_id)",
    "CREATE INDEX IF NOT EXISTS idx_database_caso ON dim_database(caso_id)",
]

_COLUMNS_TELEMETRIA = ("caso_id", "timestamp", "nodo", "fuente", "metrica_o_error", "valor", "detalles")
_COLUMNS_WAIT_EVENTS = ("event_id", "caso_id", "snapshot_id", "host", "evento", "wait_class", "waits", "tiempo_s", "pct_dbtime")
_CHUNK_SIZE = 5000  # filas por sentencia INSERT -- acota memoria/tamano de SQL por lote


def _normalizar_timestamp(ts, contexto: str):
    """Acepta un datetime o un string ISO 8601 y devuelve siempre un
    datetime (o None). Centraliza la validacion que usan tanto
    bulk_insert_telemetria() como cualquier otro metodo que reciba un
    timestamp crudo desde un parser. Lanza ValueError si no es ninguno de
    los 2 tipos aceptados -- mismo criterio defensivo que la version
    anterior del archivo (fallar rapido con un mensaje claro en vez de
    insertar un timestamp corrupto en silencio)."""
    if ts is None:
        return None
    if isinstance(ts, datetime):
        return ts
    if isinstance(ts, str):
        try:
            return datetime.fromisoformat(ts)
        except ValueError as e:
            raise ValueError(f"{contexto}: timestamp '{ts}' no es ISO 8601 valido") from e
    raise ValueError(
        f"{contexto}: timestamp debe ser datetime o string ISO 8601, vino {type(ts).__name__}"
    )


class ForensicStorage:
    """Conexion a la base de datos DuckDB del caso + DDL del esquema
    dimensional completo (8 tablas), asegurado al instanciar.

    Una instancia = una conexion abierta a un archivo .duckdb. Usar como
    context manager (`with ForensicStorage(...) as st:`) o llamar
    close() explicitamente al terminar.
    """

    def __init__(self, db_path: str = "caso_analisis.duckdb", limpiar_al_conectar: bool = True):
        self.db_path = db_path
        self.filas_eliminadas_al_conectar = 0
        self._con = duckdb.connect(db_path)
        for ddl in _DDL_TABLAS:
            self._con.execute(ddl)
        for ddl in DDL_INDICES:
            self._con.execute(ddl)

        # Contadores de ID en memoria -- ver nota "IDs en memoria" en el
        # docstring del modulo sobre por que NO son una SEQUENCE de
        # DuckDB. Arrancan en 1 y se resetean a 1 en _limpiar_datos_previos()
        # cuando esta limpia, porque cada corrida de ingerir_carpeta()
        # reprocesa el caso completo desde una base vacia.
        self._next_infra_id = 1
        self._next_db_id = 1
        self._next_snapshot_id = 1
        self._next_event_id = 1

        if limpiar_al_conectar:
            self._limpiar_datos_previos()
        log.info("ForensicStorage conectado a %s (esquema dimensional de 8 tablas listo)", db_path)

    def _limpiar_datos_previos(self):
        """Vacia las 8 tablas si alguna ya tenia filas de una corrida
        anterior -- ver nota de idempotencia en el docstring del modulo.
        Cuenta el total de filas entre las 8 tablas; si es >0, vacia las
        8 (no solo la que tenia filas, porque dim_caso/dim_infraestructura/
        dim_database y las tablas fact_* de una corrida anterior son
        inconsistentes entre si si se dejan mezcladas con una corrida
        nueva) y resetea a 1 los 4 contadores de ID en memoria.

        Nunca lanza: si el COUNT(*) o el DELETE fallan por algun motivo
        raro (base corrupta, etc.), se deja un warning y se continua --
        peor es tumbar la ingesta completa por no poder limpiar."""
        try:
            total = 0
            for tabla in _TODAS_LAS_TABLAS:
                (n,) = self._con.execute(f"SELECT count(*) FROM {tabla}").fetchone()
                total += n
        except Exception as e:
            log.warning("ForensicStorage: no se pudo contar filas previas en %s (%s) -- "
                        "se continua sin limpiar.", self.db_path, e)
            return
        if not total:
            return
        try:
            for tabla in _TODAS_LAS_TABLAS:
                self._con.execute(f"DELETE FROM {tabla}")
            self.filas_eliminadas_al_conectar = total
            self._next_infra_id = 1
            self._next_db_id = 1
            self._next_snapshot_id = 1
            self._next_event_id = 1
            log.warning(
                "ForensicStorage: %d fila(s) existente(s) repartidas en las 8 tablas de %s se "
                "eliminaron antes de esta ingesta -- cada corrida de ingerir_carpeta() reprocesa "
                "la carpeta del caso completa, asi que la base debe reflejar solo la corrida "
                "actual, nunca la suma de varias corridas. Si necesitas conservar corridas "
                "anteriores, usa un --db distinto por corrida.", total, self.db_path,
            )
        except Exception as e:
            log.warning("ForensicStorage: no se pudo limpiar %s antes de la ingesta (%s) -- "
                        "las filas de corridas anteriores pueden quedar duplicadas.",
                        self.db_path, e)

    @property
    def con(self):
        """Conexion DuckDB cruda, para que capas superiores (router,
        parser de AWR, ai/engine.py, etc.) puedan correr sus propias
        consultas SQL de analisis sin que esta clase tenga que exponer
        un metodo nuevo por cada caso de uso."""
        return self._con

    # -- dim_caso -----------------------------------------------------

    def registrar_caso(self, caso_id: str, nombre: str = None) -> None:
        """UPSERT de un caso en dim_caso: si caso_id ya existe, actualiza
        nombre/creado_en; si no, lo crea. Se verifico empiricamente que
        esta version de DuckDB (1.5.6) soporta `ON CONFLICT ... DO
        UPDATE` de forma nativa (ver nota en el docstring del modulo),
        asi que se usa directo en vez del patron DELETE+INSERT.

        creado_en es datetime.now() si no se pasa nada -- llamar esto 2
        veces con el mismo caso_id nunca duplica la fila ni lanza, solo
        actualiza los campos (idempotente por diseno, igual que el resto
        de esta clase)."""
        self._con.execute(
            "INSERT INTO dim_caso VALUES (?, ?, ?) "
            "ON CONFLICT (caso_id) DO UPDATE SET nombre = excluded.nombre, "
            "creado_en = excluded.creado_en",
            (caso_id, nombre, datetime.now()),
        )

    # -- dim_infraestructura / dim_database ----------------------------

    def insertar_infraestructura(self, caso_id, host, cpus=None, cores=None, sockets=None,
                                  mem_gb=None, kernel=None, num_cpus=None, busy_time=None,
                                  idle_time=None, iowait_time=None) -> int:
        """Inserta un snapshot de hardware/OS de un host en
        dim_infraestructura (tipicamente de oclumon/sar). Devuelve el
        infra_id asignado (el contador en memoria, incrementado despues
        de insertar)."""
        infra_id = self._next_infra_id
        self._con.execute(
            "INSERT INTO dim_infraestructura VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (infra_id, caso_id, host, cpus, cores, sockets, mem_gb, kernel, num_cpus,
             busy_time, idle_time, iowait_time, datetime.now()),
        )
        self._next_infra_id += 1
        return infra_id

    def insertar_database(self, caso_id, host, db_name=None, instance_name=None,
                           release=None, rac=None) -> int:
        """Inserta la identidad de una instancia/release en dim_database
        (tipicamente extraida de la cabecera de un reporte AWR). Devuelve
        el db_id asignado."""
        db_id = self._next_db_id
        self._con.execute(
            "INSERT INTO dim_database VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (db_id, caso_id, host, db_name, instance_name, release, rac, datetime.now()),
        )
        self._next_db_id += 1
        return db_id

    # -- fact_telemetria_so ---------------------------------------------

    def bulk_insert_telemetria(self, caso_id: str, filas: list) -> int:
        """Inserta una lista de diccionarios en fact_telemetria_so, cada
        uno con claves timestamp/nodo/fuente/metrica_o_error/valor/
        detalles (SIN caso_id -- parsers/oclumon.py y parsers/sar.py no
        lo conocen ni deben cambiarse para agregarlo; se estampa aqui, a
        partir del parametro caso_id de esta funcion, igual para las N
        filas del lote).

        Misma logica de la version anterior de este metodo (entonces
        llamado bulk_insert(), sobre eventos_forenses): lotes de
        _CHUNK_SIZE filas, dentro de UNA sola transaccion explicita (todo
        o nada: si una fila del lote completo falla -p.ej. un timestamp
        invalido-, no queda insertada ni media fila). timestamp acepta un
        datetime o un string ISO 8601 (se normaliza con
        _normalizar_timestamp). valor y detalles pueden faltar o venir en
        None -- se insertan como NULL.

        Devuelve cuantas filas se insertaron (0 si la lista viene vacia,
        sin tocar la base)."""
        if not filas:
            return 0

        rows = []
        for i, fila in enumerate(filas):
            ts = _normalizar_timestamp(fila.get("timestamp"), f"fila {i}")
            rows.append((
                caso_id, ts, fila.get("nodo"), fila.get("fuente"),
                fila.get("metrica_o_error"), fila.get("valor"), fila.get("detalles"),
            ))

        self._con.execute("BEGIN TRANSACTION")
        try:
            for start in range(0, len(rows), _CHUNK_SIZE):
                chunk = rows[start:start + _CHUNK_SIZE]
                # DuckDB vectoriza UNNEST sobre listas columnares. El patrón
                # anterior construía 35.000 placeholders y parámetros por
                # lote de 5.000 filas, coste dominante en CHM grandes.
                columnas = [list(col) for col in zip(*chunk)]
                selectores = ", ".join("unnest(?)" for _ in _COLUMNS_TELEMETRIA)
                self._con.execute(
                    f"INSERT INTO fact_telemetria_so SELECT {selectores}", columnas
                )
            self._con.execute("COMMIT")
        except Exception:
            self._con.execute("ROLLBACK")
            raise

        log.info("bulk_insert_telemetria: %d filas insertadas en fact_telemetria_so (caso %s)",
                  len(rows), caso_id)
        return len(rows)

    # -- fact_awr_snapshots / fact_awr_wait_events ----------------------

    def insertar_awr_snapshot(self, caso_id, host, awr_file, begin_snap_id=None, end_snap_id=None,
                               begin_ts=None, end_ts=None, db_cpu_per_sec=None, db_time_per_sec=None,
                               logical_reads_per_sec=None, physical_reads_per_sec=None,
                               physical_writes_per_sec=None, parses_per_sec=None, executes_per_sec=None,
                               num_cpus=None, busy_time=None,
                               idle_time=None, iowait_time=None) -> int:
        """Inserta un snapshot AWR en fact_awr_snapshots. Calcula
        elapsed_seg y db_time_seg en Python (nunca se inventan si falta
        un dato: ambos quedan en None si no se puede calcular con
        precision) y deja que DuckDB calcule `aas` solo, como columna
        GENERATED (ver nota en el docstring del modulo) -- por eso esta
        funcion jamas inserta un valor de aas explicitamente.

        - elapsed_seg = (end_ts - begin_ts).total_seconds(), SOLO si
          begin_ts y end_ts son ambos datetime no-None. Si falta
          cualquiera de los 2, elapsed_seg queda en None.
        - db_time_seg = db_time_per_sec * elapsed_seg, SOLO si ambos son
          no-None (depende de elapsed_seg, asi que si ese quedo en None,
          db_time_seg tambien).

        Devuelve el snapshot_id asignado (el contador en memoria,
        incrementado despues de insertar)."""
        elapsed_seg = None
        if isinstance(begin_ts, datetime) and isinstance(end_ts, datetime):
            elapsed_seg = (end_ts - begin_ts).total_seconds()

        db_time_seg = None
        if db_time_per_sec is not None and elapsed_seg is not None:
            db_time_seg = db_time_per_sec * elapsed_seg

        snapshot_id = self._next_snapshot_id
        self._con.execute(
            "INSERT INTO fact_awr_snapshots ("
            "snapshot_id, caso_id, host, awr_file, begin_snap_id, end_snap_id, begin_ts, end_ts, "
            "elapsed_seg, db_cpu_per_sec, db_time_per_sec, logical_reads_per_sec, "
            "physical_reads_per_sec, physical_writes_per_sec, parses_per_sec, executes_per_sec, "
            "num_cpus, busy_time, idle_time, "
            "iowait_time, db_time_seg"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (snapshot_id, caso_id, host, awr_file, begin_snap_id, end_snap_id, begin_ts, end_ts,
             elapsed_seg, db_cpu_per_sec, db_time_per_sec, logical_reads_per_sec,
             physical_reads_per_sec, physical_writes_per_sec, parses_per_sec, executes_per_sec,
             num_cpus, busy_time, idle_time,
             iowait_time, db_time_seg),
        )
        self._next_snapshot_id += 1
        return snapshot_id

    def bulk_insert_wait_events(self, caso_id, snapshot_id, host, eventos: list) -> int:
        """Inserta una lista de wait events de AWR (cada item: un dict
        con claves evento/wait_class/waits/tiempo_s/pct_dbtime --
        cualquiera salvo 'evento' puede ser None) en
        fact_awr_wait_events, estampando caso_id/snapshot_id/host en cada
        fila. event_id se asigna de forma incremental desde
        self._next_event_id, avanzando el contador por cada fila
        insertada (asi que IDs quedan unicos y crecientes dentro de la
        misma corrida).

        Igual que bulk_insert_telemetria(): lotes de _CHUNK_SIZE filas,
        una sola transaccion explicita (todo o nada). Nunca inserta
        avg_wait_ms -- es columna GENERATED, DuckDB la calcula sola (ver
        nota en el docstring del modulo).

        Devuelve cuantas filas se insertaron (0 si la lista viene vacia)."""
        if not eventos:
            return 0

        rows = []
        for evento in eventos:
            event_id = self._next_event_id
            rows.append((
                event_id, caso_id, snapshot_id, host,
                evento.get("evento"), evento.get("wait_class"), evento.get("waits"),
                evento.get("tiempo_s"), evento.get("pct_dbtime"),
            ))
            self._next_event_id += 1

        self._con.execute("BEGIN TRANSACTION")
        try:
            for start in range(0, len(rows), _CHUNK_SIZE):
                chunk = rows[start:start + _CHUNK_SIZE]
                columnas = [list(col) for col in zip(*chunk)]
                selectores = ", ".join("unnest(?)" for _ in _COLUMNS_WAIT_EVENTS)
                self._con.execute(
                    f"INSERT INTO fact_awr_wait_events SELECT {selectores}", columnas
                )
            self._con.execute("COMMIT")
        except Exception:
            self._con.execute("ROLLBACK")
            raise

        log.info("bulk_insert_wait_events: %d filas insertadas en fact_awr_wait_events "
                  "(caso %s, snapshot %s)", len(rows), caso_id, snapshot_id)
        return len(rows)

    def close(self):
        self._con.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        return False
