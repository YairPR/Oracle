"""
core/component_catalog.py

Contratos de datos (Pydantic) + catalogo versionado de componentes de UI,
construidos a partir de la propuesta del usuario del 2026-10-01 ("Oracle
Diagnostic Lab"): un dashboard autogenerativo por episodio, donde el motor
de analisis (no una plantilla fija) decide que paneles mostrar segun la
casuistica detectada y la cobertura real de datos disponible.

Por que Pydantic aca y no dicts sueltos (motivo pedido explicitamente):
cada pieza que cruza la frontera "motor Python" -> "template Jinja2" ->
"JSON embebido para el bundle TypeScript/ECharts" pasa por un modelo
validado una sola vez, en vez de que cada capa downstream tenga que volver
a adivinar que claves puede esperar encontrar. Un campo faltante o mal
tipado revienta ACA, en el borde del motor analitico, en vez de aparecer
como un `undefined` silencioso en el HTML final -- consistente con la
disciplina del resto del proyecto (nunca fallar en silencio).

Tres bloques de salida, tal como los describio el usuario:
  - Hechos: eventos, metricas y entidades con referencia a su archivo de
    origen (ver `Evento`/`Metrica` mas abajo).
  - Diagnostico: episodios interpretados, impacto, hipotesis, limitaciones
    (ver `core/dashboard_engine.py`, que construye esto a partir de
    `core/episode_engine.py` + `core/correlacion.py` ya existentes).
  - Presentacion: que componentes del catalogo de abajo se activan, con
    que paneles, para ESTE caso puntual (ver `Presentacion` mas abajo).

Catalogo de componentes: originalmente 10 casuisticas (la mitad
derivadas de alert log/Clusterware/trace). Desde el Hito de
simplificacion de alcance (2026-10, decision explicita del usuario:
"solo series de telemetria -- oclumon, sar, awr"), el catalogo quedo
reducido a las 5 casuisticas que un episodio de oclumon puede disparar
por si solo: interconnect, asm_io, memory_pressure, cpu_saturation y el
fallback unknown_event. node_down/instance_termination/dataguard/
ora_critical/job_sql_error se retiraron porque dependian enteramente de
codigos ORA-/CRS- o patrones de texto de alert log, fuente que ya no
forma parte de este pipeline.

Cada entrada tiene un icono base (vendorizado en `core/icons.py`),
paneles obligatorios, paneles OPCIONALES (solo si hay metricas
compatibles + cobertura temporal real -- la decision la toma
`core/dashboard_engine.py`, este modulo solo declara la regla) y una
accion de "falta de datos" explicita en vez de dejar un hueco en blanco.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator

# ---------------------------------------------------------------------------
# Contratos de datos (Hechos)
# ---------------------------------------------------------------------------


class Evento(BaseModel):
    """Un hecho discreto -- un hallazgo de texto (codigo ORA-/CRS-/TNS-,
    patron critico de alert log, bloque de trace) con referencia a su
    archivo de origen. Analogo a una fila de `eventos_forenses`, pero
    tipado y validado en el borde de salida hacia el template."""

    timestamp: datetime
    nodo: Optional[str] = None
    fuente: str  # oclumon | sar | awr -- alcance acotado (ver Hito de simplificacion)
    codigo: Optional[str] = None  # ya no aplica (sin alert log con codigos ORA-/CRS-), se deja por compatibilidad
    etiqueta: str  # descripcion corta legible
    detalle: Optional[str] = None  # linea original (se escapa en el template)
    severidad: Literal["critical", "warning", "info"] = "info"
    archivo_origen: Optional[str] = None

    @field_validator("fuente")
    @classmethod
    def _fuente_conocida(cls, v):
        validas = {"oclumon", "sar", "awr"}
        if v not in validas:
            raise ValueError(f"fuente '{v}' no es una de {sorted(validas)}")
        return v


class Metrica(BaseModel):
    """Un punto de serie de tiempo (p.ej. un valor de cpu_pct en un
    instante dado, para un nodo). `valor=None` esta permitido a proposito
    -- un hueco de muestreo real, nunca se interpola."""

    timestamp: datetime
    nodo: Optional[str] = None
    serie: str  # cpu_pct, memfree_mb, gipcd_avgms:eth3, db_cpu_per_sec, ...
    valor: Optional[float] = None
    unidad: Optional[str] = None


class Entidad(BaseModel):
    """Una instancia, nodo o archivo referenciado por un hecho -- permite
    que el panel de evidencias enlace 'de vuelta' a su origen sin que el
    template tenga que re-derivar esa relacion."""

    tipo: Literal["nodo", "instancia", "archivo"]
    nombre: str
    archivo_origen: Optional[str] = None


class Hechos(BaseModel):
    eventos: list[Evento] = Field(default_factory=list)
    metricas: list[Metrica] = Field(default_factory=list)
    entidades: list[Entidad] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Contratos de datos (Diagnostico)
# ---------------------------------------------------------------------------


class Hipotesis(BaseModel):
    """Una explicacion candidata para el episodio, NUNCA presentada como
    certeza salvo que la evidencia la confirme -- ver `estado` (mismo
    principio que ya aplicaba `generar_veredicto()`/`calcular_estado_salud()`
    en ai/engine.py: el motor determinista nunca inventa confianza que los
    datos no respaldan)."""

    titulo: str
    detalle: str
    estado: Literal["confirmada", "en_estudio", "sin_evidencia"] = "en_estudio"


class Limitacion(BaseModel):
    """Una limitacion de cobertura explicita -- p.ej. 'solo se encontro
    alert log de 1 de los 2 nodos', 'sin datos de AWR en este caso'. Se
    muestra siempre que aplique, nunca se omite para que el informe se vea
    mas completo de lo que los datos permiten."""

    descripcion: str


class EpisodioDiagnostico(BaseModel):
    """Un episodio ya interpretado, listo para que el motor de
    presentacion decida que componente del catalogo activar. Envuelve al
    episodio crudo de `core/episode_engine.py` (node/cat/t_ini/t_fin/...)
    con el finding_type que dispara la seleccion de componente."""

    id: str
    finding_type: str  # ver CATALOGO mas abajo -- la clave que activa un componente
    nodo: Optional[str] = None
    inicio: datetime
    fin: datetime
    severidad: Literal["critical", "warning", "info"] = "info"
    resumen: str
    interpretacion: str
    impacto: Optional[str] = None
    hipotesis: list[Hipotesis] = Field(default_factory=list)
    limitaciones: list[Limitacion] = Field(default_factory=list)
    evidencia_ids: list[int] = Field(default_factory=list)  # indices sobre Hechos.eventos


class Diagnostico(BaseModel):
    episodios: list[EpisodioDiagnostico] = Field(default_factory=list)
    estado_global: Literal["OK", "WARNING", "CRITICAL"] = "OK"
    motivos_estado_global: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Catalogo de componentes (Presentacion)
# ---------------------------------------------------------------------------

MissingDataAction = Literal["show_coverage_notice", "events_only", "hide_optional"]


class ActivateWhen(BaseModel):
    finding_type: str


class MissingData(BaseModel):
    action: MissingDataAction = "show_coverage_notice"
    mensaje: Optional[str] = None


class ComponenteDefinicion(BaseModel):
    """Una entrada del catalogo versionado -- exactamente la estructura que
    propuso el usuario (activate_when / panels / optional_panels /
    missing_data), mas `icon` (clave hacia `core/icons.py`) y `label`
    (texto legible para el header del panel)."""

    id: str
    label: str
    icon: str  # clave en core.icons.ICONOS
    activate_when: ActivateWhen
    panels: list[str]  # siempre se muestran si el componente se activa
    optional_panels: list[str] = Field(default_factory=list)  # solo si hay cobertura
    missing_data: MissingData = Field(default_factory=MissingData)


class ComponenteActivado(BaseModel):
    """La version YA RESUELTA de un ComponenteDefinicion para un episodio
    concreto -- lo que arma `core/dashboard_engine.py` despues de evaluar
    cobertura real de datos. `optional_panels_activos` es un subconjunto
    de `definicion.optional_panels`; lo que quedo afuera se documenta en
    `notas_cobertura` en vez de desaparecer sin explicacion."""

    episodio_id: str
    definicion: ComponenteDefinicion
    optional_panels_activos: list[str] = Field(default_factory=list)
    notas_cobertura: list[str] = Field(default_factory=list)
    # Panel que grafica la metrica REAL que disparo este episodio puntual
    # (ver resolver_panel_disparador() mas abajo) -- None si la categoria
    # del episodio todavia no tiene una serie propia expuesta (device_state/
    # device_wait/fs_full: oclumon solo da eventos discretos para esas, sin
    # serie de tiempo que graficar). El template lo destaca por separado del
    # resto de optional_panels_activos, que quedan como contexto adicional.
    panel_disparador: Optional[str] = None


class Presentacion(BaseModel):
    componentes: list[ComponenteActivado] = Field(default_factory=list)
    series_relevantes: dict[str, bool] = Field(default_factory=dict)


class InformeCompleto(BaseModel):
    """El contrato de nivel superior -- lo que `core/dashboard_engine.py`
    produce y lo que el template Jinja2 recibe como unico objeto validado."""

    hechos: Hechos
    diagnostico: Diagnostico
    presentacion: Presentacion


# ---------------------------------------------------------------------------
# El catalogo en si -- 5 casuisticas que un episodio de oclumon puede
# disparar por si solo (ver aviso de alcance en el docstring del modulo).
# ---------------------------------------------------------------------------
# Nombres de panel: strings libres a proposito (no un enum cerrado) -- un
# panel nuevo se agrega sin tocar el modelo Pydantic, solo el catalogo de
# abajo + su partial Jinja2 correspondiente en templates/panels/.

CATALOGO: dict[str, ComponenteDefinicion] = {
    "network": ComponenteDefinicion(
        id="network", label="Red del host e interfaces", icon="interconnect",
        activate_when=ActivateWhen(finding_type="network"),
        panels=["episode_summary", "evidence_table"], optional_panels=[],
        missing_data=MissingData(action="events_only", mensaje="Detalle por interfaz y contadores del host en la vista Red; no se atribuyen a PRIVATE sin evidencia."),
    ),
    "interconnect": ComponenteDefinicion(
        id="interconnect",
        label="Interconnect",
        icon="interconnect",
        activate_when=ActivateWhen(finding_type="interconnect"),
        panels=["episode_summary", "evidence_table"],
        # Antes solo 3 paneles fijos (latencia/trafico/protocol_errors_chart
        # generico, este ultimo SIN grafico real -- ver nota retirada de
        # core/html_builder.py). Desde que core/episode_engine.py expone
        # ip_reasfail/udp_rcverr/descartes/errores-de-NIC como series reales
        # en series_por_nodo, cada categoria de episodio tiene su propio
        # panel -- ver resolver_panel_disparador() mas abajo, que decide
        # CUAL de estos es la metrica que realmente disparo cada episodio
        # puntual (los demas quedan como contexto secundario).
        optional_panels=["interconnect_latency_chart", "interconnect_traffic_chart",
                          "nic_discards_chart", "nic_link_errors_chart",
                          "protocol_ip_reasfail_chart", "protocol_udp_rcverr_chart"],
        missing_data=MissingData(
            action="events_only",
            mensaje="Sin metricas de interconnect (oclumon) con cobertura en esta ventana -- "
            "se listan solo los eventos/errores de red encontrados en los logs disponibles.",
        ),
    ),
    "asm_io": ComponenteDefinicion(
        id="asm_io",
        label="ASM / I-O",
        icon="asm_io",
        activate_when=ActivateWhen(finding_type="asm_io"),
        panels=["episode_summary", "evidence_table"],
        optional_panels=["io_latency_chart", "device_state_table"],
        missing_data=MissingData(action="events_only"),
    ),
    "memory_pressure": ComponenteDefinicion(
        id="memory_pressure",
        label="Presion de memoria",
        icon="memory_pressure",
        activate_when=ActivateWhen(finding_type="memory_pressure"),
        panels=["episode_summary", "evidence_table"],
        optional_panels=["memory_by_node_chart", "swap_by_node_chart"],
        missing_data=MissingData(action="events_only"),
    ),
    "cpu_saturation": ComponenteDefinicion(
        id="cpu_saturation",
        label="Saturacion de CPU",
        icon="cpu_saturation",
        activate_when=ActivateWhen(finding_type="cpu_saturation"),
        panels=["episode_summary", "evidence_table"],
        optional_panels=["cpu_by_node_chart", "cpu_queue_chart"],
        missing_data=MissingData(action="events_only"),
    ),
    "unknown_event": ComponenteDefinicion(
        id="unknown_event",
        label="Evento desconocido",
        icon="unknown_event",
        activate_when=ActivateWhen(finding_type="unknown_event"),
        panels=["episode_summary", "evidence_table"],
        optional_panels=[],
        missing_data=MissingData(
            action="show_coverage_notice",
            mensaje="Texto original disponible, sin clasificar contra ninguna casuistica "
            "conocida -- revisar manualmente.",
        ),
    ),
}


# ---------------------------------------------------------------------------
# Mapeo categoria de episodio -> finding_type del catalogo de arriba
# ---------------------------------------------------------------------------
# Un solo lugar (no duplicado en dashboard_engine.py) que traduce las
# categorias que produce core/episode_engine.py (ver INTERP_KB) hacia uno
# de los 5 finding_type de arriba. Nunca se deja un episodio sin mapeo --
# lo que no matchea nada cae en "unknown_event" explicitamente (ver
# `resolver_finding_type()` mas abajo), nunca se descarta en silencio.
# (El mapeo de codigos ORA-/CRS-/TNS- y de patrones de alert log se
# retiro junto con esa fuente -- ver Hito de simplificacion de alcance.)

_CATEGORIA_A_FINDING = {
    "swap": "memory_pressure",
    "cpu_queue": "cpu_saturation",
    "nic_errors_hw": "network",
    "interconnect_burst": "interconnect",
    "nic_discards": "network",
    "nic_link_errors": "network",
    "nic_latency": "network",
    "ip_reasfail": "network",
    "udp_rcverr": "network",
    "tcp_retrans": "network",
    "device_state": "asm_io",
    "device_wait": "asm_io",
    "fs_full": "asm_io",
}


def resolver_finding_type(categoria: Optional[str] = None) -> str:
    """Traduce una categoria de episodio (`core/episode_engine.py`) a uno
    de los finding_type del catalogo de arriba. Nunca lanza, nunca
    devuelve None -- lo no reconocido cae en 'unknown_event' de forma
    explicita (consistente con el resto del proyecto: un evento no
    mapeado se muestra igual, nunca desaparece)."""
    if categoria and categoria in _CATEGORIA_A_FINDING:
        return _CATEGORIA_A_FINDING[categoria]
    return "unknown_event"


# ---------------------------------------------------------------------------
# Mapeo categoria de episodio -> panel OPCIONAL que grafica su metrica REAL
# disparadora (rediseno 2026-10-02: "cada episodio debe graficar la metrica
# especifica que lo disparo, no un par fijo de paneles genericos").
# ---------------------------------------------------------------------------
# Solo se mantiene un panel primario cuando representa el recurso real.
# El resto se explora por entidad en las vistas OCLUMON.
# Host counters and arbitrary interfaces must never substitute PRIVATE series.
_CATEGORIA_A_PANEL_PRIMARIO = {
    "swap": "swap_by_node_chart",
    "cpu_queue": "cpu_queue_chart",
    "interconnect_burst": "interconnect_traffic_chart",
}


def resolver_panel_disparador(categoria: Optional[str] = None) -> Optional[str]:
    """Devuelve el panel OPCIONAL (de los declarados en CATALOGO) que
    grafica la metrica real que disparo un episodio de esta categoria, o
    None si esa categoria todavia no tiene serie de tiempo propia (nunca
    inventa un panel que no existe en series_por_nodo)."""
    if not categoria:
        return None
    return _CATEGORIA_A_PANEL_PRIMARIO.get(categoria)
