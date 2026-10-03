"""
ai/engine.py

Orquestador analitico offline del RAC Forensic Lab. No es un chatbot de
proposito general: es un peritaje de UN caso ya cargado en DuckDB, con
una regla de diseno central que domina todo este modulo -- CERO
alucinaciones en lo determinista, e IA solo cuando el usuario la pide.

*** REDISENO DE ALCANCE (2026-10-01, decision explicita del usuario) ***
Hasta este hito, este motor encadenaba automaticamente 3 pasos dentro de
`ejecutar_caso_completo()` (analizador.py), y el ultimo (`generar_veredicto()`,
una llamada a Ollama local) era el cuello de botella real del pipeline
(~230s medidos contra el caso real) -- el usuario pidio explicitamente
"agilizar el pipeline" y mover la IA a una consulta A PEDIDO, no
automatica: *"que dentro del reporte... haya un apartado para poder
consultar a la IA... Fase 1: chat con Ollama usando el contexto del caso
ya calculado, sin RAG todavia"*. Ademas, `extraer_literatura_experta()`
(la "literatura experta" via OerrEngine/error_kb.json, codigos
ORA-/CRS-/TNS-) dependia enteramente del alert log, fuente retirada del
pipeline (ver Hito de simplificacion: solo oclumon+sar+awr) -- por eso
ese metodo, OerrEngine y la logica de codigos criticos se retiraron de
este modulo.

Lo que queda, y por que:
  1. `extraer_hechos_telemetria()` -- SOLO SQL determinista sobre el
     esquema dimensional (`fact_awr_snapshots`/`fact_awr_wait_events`
     para AWR Load Profile + Top Wait Events, `fact_telemetria_so` para
     el resumen de oclumon y de sar -- ver Hito "modelo de datos
     dimensional", 2026-10-02, migrado desde la antigua tabla plana
     `eventos_forenses`, retirada). Sigue corriendo SIEMPRE y rapido
     (es solo SQL) --
     es el contexto que alimenta tanto el estado de salud como, a
     pedido, el chat con Ollama.
  2. `calcular_estado_salud()` -- SOLO SQL, CERO participacion del LLM,
     decide de forma 100% determinista si el cluster esta
     CRITICAL/WARNING/OK (ver su docstring para los criterios exactos).
     Sigue corriendo siempre, automatico, porque es rapido y es la base
     del badge de estado del dashboard.
  3. `responder_pregunta()` (nuevo, reemplaza a `generar_veredicto()`/
     `generar_diagnostico_completo()`) -- UNICA llamada a Ollama de este
     modulo, y SOLO a pedido explicito (el endpoint `/api/preguntar` del
     modo `--servir`, ver analizador.py). Recibe el contexto YA
     calculado (hechos_telemetria + estado_salud, calculados una sola
     vez al generar el informe) mas la pregunta libre del usuario -- sin
     RAG todavia (Fase 1, por decision explicita del usuario; Fase 2
     indexaria documentacion/PDFs real).

Dependencia opcional: el cliente `ollama` (pip) es necesario SOLO para
responder_pregunta() -- si no esta instalado, o si el demonio local
`ollama serve` no esta corriendo, el resto del motor (extraer_hechos_telemetria/
calcular_estado_salud) sigue funcionando igual; responder_pregunta()
devuelve un string de aviso en vez de lanzar una excepcion.
"""

import re
import logging

import duckdb

log = logging.getLogger("rac_forensic_lab.ai.engine")

try:
    import ollama
    _OLLAMA_IMPORTADO = True
except ImportError:
    ollama = None
    _OLLAMA_IMPORTADO = False
    log.warning(
        "libreria 'ollama' no instalada -- responder_pregunta() va a devolver "
        "un aviso en vez de una respuesta real. Instalar con: "
        "pip install ollama (dentro del venv de rac-lab)."
    )

MODELO_DEFAULT = "qwen2.5-coder:7b"

# Las 4 metricas de Load Profile que ya carga parsers/awr.py.
LOAD_PROFILE_METRICAS = (
    "db_cpu_per_sec",
    "logical_reads_per_sec",
    "physical_reads_per_sec",
    "physical_writes_per_sec",
)

UMBRAL_PCT_DBTIME = 5.0  # "mas del 5% de impacto" -- pedido explicito del hito

# -- Umbrales del motor de decision de salud (calcular_estado_salud(),
# ver mas abajo). UMBRAL_GIPCD_AVGMS_CRITICO se retiro (dependia de
# Clusterware/gipcd, fuente fuera de alcance desde el Hito de
# simplificacion).
UMBRAL_CPU_WARNING_PCT = 80.0  # % -- pedido explicito del hito
# IPReasFail/TCPRetraSeg son contadores ACUMULATIVOS (ver
# parsers/oclumon.py) -- un "salto vertical brusco" se mide como el delta
# mas grande entre 2 muestras consecutivas del mismo nodo para la misma
# metrica. Sin un numero oficial de Oracle para esto, se calibro contra
# el unico dump real disponible hoy (chm_nodo2.txt, nodo bov-racsalud-302,
# caso DEPT300): el ruido de fondo normal entre muestras de ~5s es de 0-5
# TCPRetraSeg/muestra, mientras que la ventana real del incidente trae
# saltos de 17 a 120/muestra -- este umbral separa limpiamente ambos
# casos en el unico incidente real disponible hoy. Es, a proposito, una
# constante configurable y revisable con mas casos reales.
UMBRAL_SALTO_PROTO_ERRORS = 50.0

# Prompt de la Fase 1 del chat con Ollama (sin RAG todavia, decision
# explicita del usuario): el modelo SOLO ve el contexto ya calculado del
# caso (HECHOS_TELEMETRIA + ESTADO_SALUD_CALCULADO, ambos 100% SQL
# determinista) mas la pregunta libre que el usuario escribe en el panel
# del dashboard (modo --servir). A diferencia del viejo PROMPT_TEMPLATE
# (veredicto rigido de 3 lineas, retirado en este hito), aca se le pide
# una respuesta conversacional normal -- el usuario esta preguntando, no
# pidiendo un informe pericial formal.
PROMPT_CHAT_TEMPLATE = """Eres un asistente tecnico de Oracle RAC ayudando a un DBA a interpretar UN caso ya analizado. Respondes SOLO con base en el contexto de abajo -- nunca inventes un numero, un codigo de error o un evento que no este en HECHOS_TELEMETRIA o ESTADO_SALUD_CALCULADO. Si la pregunta pide algo que el contexto no cubre, dilo explicitamente en vez de adivinar.

=== HECHOS_TELEMETRIA (SQL determinista sobre este caso) ===
{hechos}

=== ESTADO_SALUD_CALCULADO (motor de reglas, no el LLM) ===
{estado_salud_bloque}

=== PREGUNTA DEL USUARIO ===
{pregunta}

Responde en castellano, de forma clara y directa, citando los datos concretos del contexto que respaldan tu respuesta."""


def _fmt(valor, nd=2):
    """Formatea un float para el prompt sin ruido de precision binaria.
    None se formatea como 'N/D' -- nunca se inventa un cero."""
    if valor is None:
        return "N/D"
    try:
        return f"{float(valor):.{nd}f}"
    except (TypeError, ValueError):
        return str(valor)


class RootCauseEngine:
    """Orquestador analitico offline. Una instancia = una conexion de
    SOLO LECTURA a un .duckdb de caso ya cargado.

    read_only=True a proposito: este motor nunca debe escribir en el
    esquema dimensional (dim_*/fact_*) -- solo lee y agrega lo que
    core/storage.py y los parsers ya insertaron.
    """

    def __init__(self, db_path: str = "caso_analisis.duckdb",
                 modelo: str = MODELO_DEFAULT, ollama_host: str = None):
        self.db_path = db_path
        self.modelo = modelo
        self.ultimo_diagnostico = {"errors": []}

        self._con = None
        try:
            self._con = duckdb.connect(db_path, read_only=True)
        except Exception as e:
            log.error("RootCauseEngine: no se pudo abrir %s en solo lectura: %s", db_path, e)
            self.ultimo_diagnostico["errors"].append(f"apertura de {db_path}: {e}")

        self._ollama_client = None
        if _OLLAMA_IMPORTADO:
            try:
                self._ollama_client = ollama.Client(host=ollama_host) if ollama_host else ollama
            except Exception as e:
                log.error("RootCauseEngine: no se pudo preparar el cliente de ollama: %s", e)
                self.ultimo_diagnostico["errors"].append(f"cliente ollama: {e}")

    def close(self):
        if self._con is not None:
            self._con.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
        return False

    def _query(self, sql, params=None, etiqueta=""):
        """SELECT con red de seguridad -- una consulta que falla (tabla
        vacia, columna inesperada en un .duckdb viejo, etc.) nunca debe
        tumbar toda la extraccion de hechos. Devuelve lista de tuplas
        vacia si falla, y lo registra en el diagnostico."""
        if self._con is None:
            return []
        try:
            return self._con.execute(sql, params or []).fetchall()
        except Exception as e:
            msg = f"query '{etiqueta}': {e}"
            log.warning("RootCauseEngine: %s", msg)
            self.ultimo_diagnostico["errors"].append(msg)
            return []

    # -- Sub-tarea 5.1: Extractor de Hechos por Ventanas Temporales ----

    def extraer_hechos_telemetria(self) -> str:
        """Ejecuta los 3 queries analiticos pedidos (Load Profile
        promedio/pico, Top Foreground Events >5% de impacto, picos de
        gipcd_avgms) y los consolida en un string estructurado y legible
        -- este string es exactamente lo que ve el LLM como
        'HECHOS_TELEMETRIA' en el prompt de 5.3, asi que cada linea debe
        poder verificarse a mano contra el mismo .duckdb."""
        partes = []

        # --- Load Profile: promedio/pico/minimo entre todos los
        # snapshots AWR cargados (puede haber mas de uno por caso).
        # Migrado (Hito "modelo de datos dimensional", 2026-10-02): las 4
        # metricas ya son columnas propias de fact_awr_snapshots (antes
        # eran filas con metrica_o_error de eventos_forenses) -- se usa
        # UNPIVOT para volver a la forma "una fila por metrica" sin
        # repetir 4 SELECTs casi iguales a mano. Verificado
        # empiricamente contra DuckDB 1.5.6: UNPIVOT excluye NULLs por
        # defecto, asi que un snapshot sin una metrica puntual no
        # contamina el avg/min/max de las demas.
        try:
            columnas = ", ".join(LOAD_PROFILE_METRICAS)
            filas = self._query(
                f"""
                SELECT metrica, avg(valor), max(valor), min(valor), count(*)
                FROM fact_awr_snapshots
                UNPIVOT (valor FOR metrica IN ({columnas}))
                GROUP BY metrica
                ORDER BY metrica
                """,
                etiqueta="load_profile",
            )
        except Exception as e:
            filas = []
            self.ultimo_diagnostico["errors"].append(f"load_profile (armado de query): {e}")

        bloque = ["=== LOAD PROFILE (AWR, agregado entre todos los snapshots cargados) ==="]
        if filas:
            for metrica, promedio, pico, minimo, n in filas:
                bloque.append(
                    f"- {metrica}: promedio={_fmt(promedio)}, pico={_fmt(pico)}, "
                    f"minimo={_fmt(minimo)} ({n} snapshot(s))"
                )
        else:
            bloque.append("- (sin datos de Load Profile en la base)")
        partes.append("\n".join(bloque))

        # --- Top Foreground Events con >5% de impacto en DB time.
        # Migrado (Hito "modelo de datos dimensional", 2026-10-02):
        # fact_awr_wait_events ya guarda pct_dbtime/tiempo_s/waits como
        # columnas propias de LA MISMA fila (antes eran 3 filas con
        # metrica_o_error con prefijo de string, correlacionadas a mano
        # con un self-join de 3 vias) -- un simple join contra
        # fact_awr_snapshots alcanza, solo para resolver el timestamp
        # del snapshot (host ya vive directo en fact_awr_wait_events).
        filas = self._query(
            """
            SELECT coalesce(s.begin_ts, s.end_ts) AS ts, w.host AS nodo,
                   w.evento, w.pct_dbtime, w.tiempo_s, w.waits
            FROM fact_awr_wait_events w
            LEFT JOIN fact_awr_snapshots s ON s.snapshot_id = w.snapshot_id
            WHERE w.pct_dbtime > ?
            ORDER BY w.pct_dbtime DESC
            """,
            [UMBRAL_PCT_DBTIME],
            etiqueta="top_wait_events",
        )
        bloque = [f"=== TOP FOREGROUND EVENTS (AWR, > {UMBRAL_PCT_DBTIME:.0f}% de DB time) ==="]
        if filas:
            for ts, nodo, evento, pct, tiempo_s, n_waits in filas:
                detalle = f"{pct:.1f}% DB time, tiempo_total={_fmt(tiempo_s, 1)}s"
                if n_waits is not None:
                    detalle += f", waits={int(n_waits)}"
                bloque.append(f"- [{ts}] {evento}: {detalle} (nodo={nodo or 'N/D'})")
        else:
            bloque.append(f"- (ningun evento supero el {UMBRAL_PCT_DBTIME:.0f}% de DB time en la base)")
        partes.append("\n".join(bloque))

        # --- Resumen OCLUMON por nodo: CPU/IO/swap promedio+pico, y el
        # salto mas grande entre 2 muestras consecutivas de los contadores
        # acumulativos de protocolo (mismo calculo que usa
        # calcular_estado_salud() para su criterio (c), reutilizado aca
        # como dato informativo para el chat).
        filas = self._query(
            """
            SELECT nodo, metrica_o_error, avg(valor), max(valor), count(*)
            FROM fact_telemetria_so
            WHERE fuente = 'oclumon' AND metrica_o_error IN (
                'CPU_USAGE_PCT', 'IO_READ_RATE_KBPS', 'IO_WRITE_RATE_KBPS',
                'IO_OPS_PER_SEC', 'SWAP_USED_MB'
            )
            GROUP BY nodo, metrica_o_error
            ORDER BY nodo, metrica_o_error
            """,
            etiqueta="oclumon_resumen",
        )
        bloque = ["=== RESUMEN OCLUMON (CHM, por nodo) ==="]
        if filas:
            for nodo, metrica, promedio, pico, n in filas:
                bloque.append(
                    f"- {metrica} (nodo={nodo or 'N/D'}): promedio={_fmt(promedio)}, "
                    f"pico={_fmt(pico)} ({n} muestra(s))"
                )
        else:
            bloque.append("- (sin datos de oclumon en la base)")

        saltos = self._query(
            """
            SELECT metrica_o_error, nodo, max(delta) FROM (
                SELECT metrica_o_error, nodo,
                       valor - lag(valor) OVER (
                           PARTITION BY metrica_o_error, nodo ORDER BY timestamp
                       ) AS delta
                FROM fact_telemetria_so
                WHERE metrica_o_error IN ('NET_IP_REASM_FAIL', 'NET_TCP_RETRA_SEG')
            ) sub
            WHERE delta IS NOT NULL AND delta > 0
            GROUP BY metrica_o_error, nodo
            ORDER BY max(delta) DESC
            """,
            etiqueta="oclumon_saltos_proto",
        )
        if saltos:
            bloque.append("  Saltos mas grandes entre 2 muestras consecutivas (contadores "
                           "acumulativos de protocolo de red):")
            for metrica, nodo, max_delta in saltos:
                bloque.append(f"    - {metrica} (nodo={nodo or 'N/D'}): +{_fmt(max_delta, 0)}")
        partes.append("\n".join(bloque))

        # --- Resumen SAR por nodo: memoria/swap (ver parsers/sar.py --
        # todavia sin seccion de CPU/%iowait, pendiente de una muestra
        # real de sar -u).
        filas = self._query(
            """
            SELECT nodo, metrica_o_error, avg(valor), max(valor), count(*)
            FROM fact_telemetria_so
            WHERE fuente = 'sar' AND metrica_o_error IN ('MEM_USED_PCT', 'SWAP_USED_PCT')
            GROUP BY nodo, metrica_o_error
            ORDER BY nodo, metrica_o_error
            """,
            etiqueta="sar_resumen",
        )
        bloque = ["=== RESUMEN SAR (memoria/swap, por nodo) ==="]
        if filas:
            for nodo, metrica, promedio, pico, n in filas:
                bloque.append(
                    f"- {metrica} (nodo={nodo or 'N/D'}): promedio={_fmt(promedio)}%, "
                    f"pico={_fmt(pico)}% ({n} muestra(s))"
                )
        else:
            bloque.append("- (sin datos de sar en la base)")
        partes.append("\n".join(bloque))

        hechos = "\n\n".join(partes)
        log.info("extraer_hechos_telemetria: %d caracteres generados, %d error(es) en el camino",
                  len(hechos), len(self.ultimo_diagnostico["errors"]))
        return hechos

    # -- Motor de decision de salud -------------------------------------

    def calcular_estado_salud(self) -> dict:
        """Evalua de forma 100% determinista -- SOLO SQL, CERO
        participacion del LLM -- si el cluster esta CRITICAL, WARNING u
        OK. Este resultado es lo que decide el badge de estado del
        dashboard y, a pedido, el contexto que ve Ollama en el chat
        (ver responder_pregunta()) -- nunca al reves.

        CRITICAL (ver alcance acotado: ya no hay codigos ORA-/CRS-/TNS-
        ni patrones de alert log en este pipeline -- ver Hito de
        simplificacion):
          a) Un salto vertical brusco (delta entre 2 muestras
             consecutivas del mismo nodo) en los contadores de error de
             red IPReasFail/TCPRetraSeg (oclumon), por encima de
             UMBRAL_SALTO_PROTO_ERRORS (ver esa constante para la
             calibracion real del umbral).

        WARNING (solo si NINGUN CRITICAL de arriba aplico):
          a) CPU promedio (CPU_USAGE_PCT) por encima de
             UMBRAL_CPU_WARNING_PCT.
          b) Uso activo de SWAP (SWAP_USED_MB > 0) en cualquier muestra.

        OK: ninguna de las anteriores -- todas las metricas en rango
        normal.

        Nunca lanza: cada chequeo usa self._query() (que ya atrapa
        excepciones de SQL y devuelve [] si falla) -- un chequeo que
        falle simplemente no aporta ningun motivo, nunca tumba el
        calculo de los demas."""
        motivos_critical = []
        motivos_warning = []

        # -- a) saltos bruscos en contadores de PROTOCOL ERRORS ---------
        filas = self._query(
            """
            SELECT metrica_o_error, nodo, max(delta) FROM (
                SELECT metrica_o_error, nodo,
                       valor - lag(valor) OVER (
                           PARTITION BY metrica_o_error, nodo ORDER BY timestamp
                       ) AS delta
                FROM fact_telemetria_so
                WHERE metrica_o_error IN ('NET_IP_REASM_FAIL', 'NET_TCP_RETRA_SEG')
            ) sub
            WHERE delta IS NOT NULL
            GROUP BY metrica_o_error, nodo
            """,
            etiqueta="salud_saltos_proto",
        )
        for metrica, nodo, max_delta in filas:
            if max_delta is not None and max_delta > UMBRAL_SALTO_PROTO_ERRORS:
                motivos_critical.append(
                    f"salto brusco de {max_delta:.0f} en {metrica} (nodo={nodo or 'N/D'}, "
                    f"> {UMBRAL_SALTO_PROTO_ERRORS:.0f} entre 2 muestras consecutivas)"
                )

        if motivos_critical:
            return {"estado": "CRITICAL", "motivos": motivos_critical}

        # -- WARNING a) CPU promedio -------------------------------------
        filas = self._query(
            "SELECT avg(valor) FROM fact_telemetria_so WHERE metrica_o_error = 'CPU_USAGE_PCT'",
            etiqueta="salud_cpu_promedio",
        )
        if filas and filas[0][0] is not None and filas[0][0] > UMBRAL_CPU_WARNING_PCT:
            motivos_warning.append(
                f"CPU promedio de {filas[0][0]:.1f}% (> {UMBRAL_CPU_WARNING_PCT:.0f}%)"
            )

        # -- WARNING b) uso activo de SWAP --------------------------------
        filas = self._query(
            "SELECT max(valor) FROM fact_telemetria_so WHERE metrica_o_error = 'SWAP_USED_MB'",
            etiqueta="salud_swap_activo",
        )
        if filas and filas[0][0] is not None and filas[0][0] > 0:
            motivos_warning.append(f"uso activo de SWAP detectado (hasta {filas[0][0]:.0f} MB)")

        if motivos_warning:
            return {"estado": "WARNING", "motivos": motivos_warning}

        return {
            "estado": "OK",
            "motivos": ["todas las metricas en rango normal"],
        }

    # -- Contexto rapido (automatico, SIEMPRE SQL) ----------------------

    def calcular_contexto_caso(self) -> dict:
        """Lo unico que corre automaticamente al generar el informe
        (ejecutar_caso_completo() en analizador.py): extraer_hechos_telemetria()
        + calcular_estado_salud(), ambos SOLO SQL y rapidos -- el
        reemplazo directo del viejo generar_diagnostico_completo(), pero
        SIN la llamada a Ollama (ver aviso de alcance del modulo). El
        dict que devuelve es exactamente lo que necesita guardar
        analizador.py para poder alimentar responder_pregunta() despues,
        a pedido, sin tener que volver a correr SQL cada vez que el
        usuario escribe una pregunta en el chat."""
        hechos = self.extraer_hechos_telemetria()
        try:
            estado_salud = self.calcular_estado_salud()
        except Exception as e:
            log.error("calcular_estado_salud fallo inesperadamente: %s", e)
            self.ultimo_diagnostico["errors"].append(f"calcular_estado_salud: {e}")
            estado_salud = {"estado": "N/D", "motivos": [f"error al calcular: {e}"]}
        return {
            "hechos_telemetria": hechos,
            "estado_salud": estado_salud,
            "errors": list(self.ultimo_diagnostico["errors"]),
        }

    # -- Chat a pedido con Ollama (Fase 1, sin RAG) ---------------------

    def responder_pregunta(self, pregunta: str, hechos: str, estado_salud: dict) -> str:
        """UNICA llamada a Ollama de este modulo, y SOLO a pedido
        explicito (endpoint /api/preguntar del modo --servir, ver
        analizador.py) -- nunca se invoca automaticamente. 'hechos' y
        'estado_salud' son el contexto YA CALCULADO una sola vez por
        calcular_contexto_caso() al generar el informe (no se vuelve a
        consultar DuckDB en cada pregunta). Fase 1 por decision explicita
        del usuario: sin RAG todavia (sin indexar documentacion/PDFs) --
        el modelo solo ve el contexto de ESTE caso.

        Nunca lanza: cualquier problema de conectividad con el demonio
        local (apagado, puerto cerrado, modelo no descargado) se atrapa
        aca y se devuelve como string de aviso."""
        if not (pregunta or "").strip():
            return "[AVISO] Pregunta vacia -- no se consulto a Ollama."
        if not _OLLAMA_IMPORTADO:
            return (
                "[AVISO] La libreria 'ollama' no esta instalada en este entorno -- "
                "no se puede responder. Instalar con 'pip install ollama' dentro "
                "del venv de rac-lab."
            )

        estado = estado_salud.get("estado", "N/D")
        motivos = estado_salud.get("motivos") or []
        estado_salud_bloque = f"Estado: {estado}\nMotivos:\n" + "\n".join(f"  - {m}" for m in motivos)
        prompt = PROMPT_CHAT_TEMPLATE.format(
            hechos=hechos, estado_salud_bloque=estado_salud_bloque, pregunta=pregunta.strip(),
        )

        try:
            cliente = self._ollama_client or ollama
            respuesta = cliente.generate(
                model=self.modelo,
                prompt=prompt,
                options={"temperature": 0.2},
            )
            texto = (respuesta.get("response") if isinstance(respuesta, dict)
                     else getattr(respuesta, "response", None))
            texto = (texto or "").strip()
            if not texto:
                log.warning("responder_pregunta: Ollama respondio sin texto en 'response'")
                return "[AVISO] Ollama respondio pero sin contenido util."
            return texto
        except Exception as e:
            # Cubre deliberadamente CUALQUIER excepcion (conexion
            # rechazada porque 'ollama serve' esta apagado, timeout de
            # red, modelo no descargado localmente, respuesta HTTP de
            # error, lo que sea) -- un demonio local caido no debe tumbar
            # el modo --servir, solo esta respuesta puntual.
            msg = (
                f"[AVISO] No se pudo contactar al demonio local de Ollama "
                f"(¿esta corriendo 'ollama serve' y esta descargado el modelo "
                f"'{self.modelo}'?). Detalle: {type(e).__name__}: {e}."
            )
            log.warning("responder_pregunta: %s", msg)
            self.ultimo_diagnostico["errors"].append(msg)
            return msg
