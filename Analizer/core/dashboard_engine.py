"""
core/dashboard_engine.py

Motor de activacion de componentes por episodio -- la pieza que hace que
el dashboard sea "autogenerativo": el motor de analisis (no una plantilla
fija) decide que paneles mostrar segun la casuistica detectada y la
cobertura real de datos disponible.

100% determinista (SOLO reglas + los datos ya calculados por
core/episode_engine.py), CERO participacion del LLM -- misma disciplina
que ai.engine.calcular_estado_salud(). Nunca lanza: cada episodio que no
matchea nada conocido cae en el componente 'unknown_event' del catalogo
en vez de desaparecer en silencio.

Nota de alcance (Hito de simplificacion, 2026-10): este motor ya NO
agrupa eventos de alert log ni correlaciona trace (core/correlacion.py
se retiro junto con esas fuentes) -- todos los episodios vienen de
`core/episode_engine.py` (oclumon). `construir_informe()` ya no recibe
`analisis_reglas`.

Flujo (ver core/component_catalog.py para los modelos Pydantic):
  1. Cada episodio de oclumon se resuelve a un finding_type del catalogo
     (`component_catalog.resolver_finding_type`).
  2. Por episodio, se decide que PANELES OPCIONALES activar -- consultando
     cobertura REAL de datos (series_por_nodo + que fuentes tienen
     muestras para ese nodo), nunca asumiendo. Lo que no tiene cobertura
     cae en el `missing_data` declarado por el catalogo (nunca un grafico
     vacio o inventado).
  3. Se arma el objeto `InformeCompleto` (Hechos/Diagnostico/Presentacion)
     y se devuelve ya validado por Pydantic.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from core.component_catalog import (
    CATALOGO,
    Diagnostico,
    Entidad,
    EpisodioDiagnostico,
    Evento,
    Hechos,
    InformeCompleto,
    ComponenteActivado,
    Presentacion,
    resolver_finding_type,
    resolver_panel_disparador,
)

log = logging.getLogger("rac_forensic_lab.core.dashboard_engine")

# Mismo umbral que EPISODE_GAP_SECONDS (core/episode_engine.py) -- un
# solo criterio de "cercania en el tiempo" reutilizado en todo el
# proyecto.
VENTANA_SEG = 120

# Que series de series_por_nodo respaldan cada panel opcional -- si
# NINGUNA de las series listadas tiene al menos 1 punto real para el nodo
# del episodio, el panel no se activa (cae en missing_data del catalogo).
# Paneles que no aparecen aca (membership_sequence, instance_event_sequence,
# evidence_table, episode_summary, error_detail) son SIEMPRE paneles
# obligatorios (van en `panels`, no en `optional_panels`) y no pasan por
# esta tabla.
_PANEL_REQUIERE_SERIES = {
    "cpu_by_node": ["cpu_pct", "cpuq"],
    "cpu_by_node_chart": ["cpu_pct"],
    "cpu_queue_chart": ["cpuq"],
    "memory_pressure_panel": ["memfree_mb", "swapfree_mb"],
    "memory_by_node_chart": ["memfree_mb"],
    "swap_by_node_chart": ["swapfree_mb"],
    "interconnect_errors": ["interconnect_latency_ms", "interconnect_kbps"],
    "interconnect_latency_chart": ["interconnect_latency_ms"],
    "interconnect_traffic_chart": ["interconnect_kbps"],
    "nic_discards_chart": ["interconnect_nic_discards"],
    "nic_link_errors_chart": ["interconnect_nic_link_errors"],
    "protocol_ip_reasfail_chart": ["ip_reasfail"],
    "protocol_udp_rcverr_chart": ["udp_rcverr"],
    "resources_by_node": ["cpu_pct", "memfree_mb"],
}

# Paneles que el pipeline de parsers actual NUNCA puede respaldar con un
# numero real todavia (ningun parser emite lag de Data Guard ni latencia
# de I/O de ASM como serie de tiempo) -- se declaran aca EXPLICITAMENTE en
# vez de dejar que el chequeo de series de arriba los descarte en
# silencio sin decir por que. Si en el futuro se agrega un parser que SI
# produce esa serie, sacarlos de esta lista y agregar su nombre a
# _PANEL_REQUIERE_SERIES con la(s) serie(s) correspondiente(s).
_PANELES_SIN_FUENTE_HOY = {
    "dataguard_lag_chart": "Ningun parser de este pipeline extrae lag de Data Guard como serie "
    "de tiempo todavia (no hay fuente V$DATAGUARD_STATS/v$archived_log conectada).",
    "dataguard_sequence_by_thread": "Ningun parser de este pipeline arma secuencia de "
    "aplicacion por thread todavia.",
    "io_latency_chart": "Ningun parser de este pipeline extrae latencia de I/O de ASM como "
    "serie de tiempo todavia (oclumon solo da device_state/device_wait discretos).",
    "device_state_table": "oclumon detecta cambios de estado de dispositivo como evento "
    "discreto, no como tabla de estado consultable -- se muestra como evento, no como tabla.",
}


def _has_observed(points):
    if isinstance(points, dict):
        return points.get('constant') is not None or any(v is not None for v in points.get('values', []))
    return bool(points) and any(p.get('v') is not None if isinstance(p, dict) else p[1] is not None for p in points)


def _tiene_cobertura(series_por_nodo: dict, node: Optional[str], nombres_series: list) -> bool:
    """True si AL MENOS UNA de las series nombradas tiene al menos 1 punto
    real para ese nodo -- nunca asume cobertura por la sola presencia del
    nodo en series_por_nodo (un nodo puede estar presente con todas sus
    series vacias si esa metrica puntual nunca se muestreo)."""
    if not node or node not in (series_por_nodo or {}):
        return False
    datos_nodo = series_por_nodo[node]
    for nombre in nombres_series:
        puntos = datos_nodo.get(nombre)
        if _has_observed(puntos):
            return True
    return False


def _cobertura_fuentes_nodo(cobertura_por_fuente: dict, node: Optional[str]) -> list:
    """Lista de fuentes tecnicas (oclumon/sar/awr/clusterware/trace) que
    tienen AL MENOS UNA fila en eventos_forenses para ese nodo puntual --
    la pregunta literal del usuario ('si es oclumon graficamos y si es sar
    tambien y si es awr tambien') resuelta por nodo, no de forma global
    para todo el caso."""
    if not node:
        return []
    return sorted(
        fuente for fuente, nodos in (cobertura_por_fuente or {}).items() if node in (nodos or set())
    )


def _construir_eventos_hechos(eventos_discretos: list) -> list[Evento]:
    """Hechos.eventos: un Evento por cada muestra de oclumon que disparo
    una regla de deteccion (`core/episode_engine.py::detect_anomalias()`,
    expuesto tal cual bajo 'eventos_discretos'). Antes de la
    simplificacion de alcance esta tabla se armaba con alert_events +
    bloques de trace correlacionados -- esa fuente ya no existe, asi que
    la evidencia real ahora viene de las mismas muestras que ya arman los
    episodios, solo sin agrupar."""
    eventos: list[Evento] = []
    for ev in eventos_discretos or []:
        try:
            ts = datetime.fromisoformat(ev["t"])
        except (KeyError, ValueError, TypeError):
            continue
        eventos.append(Evento(
            timestamp=ts, nodo=ev.get("node"), fuente="oclumon",
            etiqueta=ev.get("cat", "evento"),
            detalle=ev.get("msg"), severidad=ev.get("sev", "info"),
        ))
    from core.oclumon_dataset import epoch
    eventos.sort(key=lambda e: epoch(e.timestamp))
    return eventos


def _evidencia_para_episodio(eventos: list[Evento], node: Optional[str],
                              inicio: datetime, fin: datetime,
                              ventana_seg: int = VENTANA_SEG) -> list[int]:
    """Indices (sobre `eventos`, el Hechos.eventos ya armado) que caen
    dentro de la ventana temporal del episodio -- mismo criterio de
    cercania que core/correlacion.py ya usa para trace<->alert, aplicado
    aca para decidir que 'Hechos' respaldan a un 'Diagnostico.episodio'
    puntual. Si se conoce el nodo del episodio, se prioriza coincidencia
    de nodo, pero no se exige (mismo motivo que correlacionar_trace_con_
    alertas(): esquemas de nombre de nodo distintos entre fuentes)."""
    desde = inicio - timedelta(seconds=ventana_seg)
    hasta = fin + timedelta(seconds=ventana_seg)
    indices = [
        i for i, ev in enumerate(eventos)
        if (bool(ev.timestamp.tzinfo)==bool(inicio.tzinfo)) and desde <= ev.timestamp <= hasta and (not node or not ev.nodo or ev.nodo == node)
    ]
    return indices[:25]  # tope defensivo -- un episodio con cientos de eventos superpuestos
    # no debe inflar evidencia_ids sin limite; la tabla de evidencia igual
    # muestra "+N adicionales" si hace falta (ver template).


def _resolver_optional_panels(definicion, node: Optional[str], series_por_nodo: dict,
                               cobertura_por_fuente: dict, node_list: list) -> tuple[list, list]:
    """Para un componente ya activado, decide cuales de sus
    optional_panels tienen cobertura real de datos para ESTE episodio
    puntual. Devuelve (paneles_activos, notas_cobertura) -- las notas
    siempre se devuelven (incluso si la lista de activos esta completa),
    para que el template pueda mostrar 'datos disponibles: oclumon, sar'
    como contexto, no solo cuando falta algo. (El panel 'related_trace_blocks'
    ya no existe en ningun ComponenteDefinicion del catalogo -- dependia
    de trace, retirado junto con esa fuente.)"""
    activos = []
    notas = []

    for panel in definicion.optional_panels:
        if panel == "resources_by_node":
            if len(node_list or []) >= 2:
                if _tiene_cobertura(series_por_nodo, node, _PANEL_REQUIERE_SERIES[panel]):
                    activos.append(panel)
            else:
                notas.append(
                    "Solo se encontro telemetria OCLUMON de 1 nodo en este caso -- no se "
                    "puede comparar recursos entre nodos para esta expulsion."
                )
            continue
        if panel in _PANELES_SIN_FUENTE_HOY:
            notas.append(_PANELES_SIN_FUENTE_HOY[panel])
            continue
        requeridas = _PANEL_REQUIERE_SERIES.get(panel)
        if requeridas is None:
            # Panel declarado en el catalogo sin regla de cobertura
            # todavia -- se activa igual (mejor mostrarlo de mas a
            # ocultarlo por una omision de esta tabla) pero queda anotado
            # para revisar cuando se agregue su regla real.
            activos.append(panel)
            notas.append(f"'{panel}' activado sin regla de cobertura especifica (revisar).")
            continue
        if _tiene_cobertura(series_por_nodo, node, requeridas):
            activos.append(panel)
        else:
            fuentes_vistas = _cobertura_fuentes_nodo(cobertura_por_fuente, node)
            if fuentes_vistas:
                notas.append(
                    f"Sin cobertura de {('/'.join(requeridas))} para el nodo {node} -- "
                    f"fuentes con datos reales de ese nodo: {', '.join(fuentes_vistas)}."
                )
            else:
                notas.append(
                    f"Sin cobertura de {('/'.join(requeridas))} para el nodo {node} -- "
                    "ninguna fuente tecnica tiene muestras de ese nodo en este caso."
                )

    return activos, notas


def construir_informe(resultado_episodios: dict,
                       estado_salud: Optional[dict], cobertura_por_fuente: dict) -> dict:
    """Punto de integracion unico -- llamado desde analizador.py
    (construir_payload()). Nunca lanza: cualquier excepcion inesperada se
    atrapa y devuelve un InformeCompleto vacio pero valido (el dashboard
    debe poder renderizar igual, solo sin paneles autogenerados, en vez de
    que falle la corrida completa por este motor nuevo).

    Ya no recibe 'analisis_reglas' (core/correlacion.py se retiro junto
    con alert log/trace -- ver Hito de simplificacion de alcance)."""
    try:
        return _construir_informe_interno(
            resultado_episodios or {}, estado_salud or {}, cobertura_por_fuente or {},
        )
    except Exception as e:
        log.warning("dashboard_engine.construir_informe: error inesperado (%s) -- "
                    "se devuelve un informe vacio, el resto del dashboard se genera igual.", e)
        return InformeCompleto(
            hechos=Hechos(), diagnostico=Diagnostico(), presentacion=Presentacion(),
        ).model_dump(mode="json")


def _construir_informe_interno(resultado_episodios: dict,
                                estado_salud: dict, cobertura_por_fuente: dict) -> dict:
    eventos_discretos = resultado_episodios.get("eventos_discretos", [])
    episodios_oclumon = resultado_episodios.get("episodios", [])
    series_por_nodo = resultado_episodios.get("series_por_nodo", {})
    node_list = resultado_episodios.get("node_list", [])

    eventos_hechos = _construir_eventos_hechos(eventos_discretos)
    hechos = Hechos(
        eventos=eventos_hechos,
        metricas=[],  # las series completas viajan aparte en el payload (motor_episodios.series_por_nodo)
        # para no duplicar miles de puntos dentro de este modelo -- ver nota en el docstring del modulo.
        entidades=[Entidad(tipo="nodo", nombre=n) for n in node_list],
    )

    episodios_diag: list[EpisodioDiagnostico] = []
    componentes: list[ComponenteActivado] = []

    for ep_crudo in episodios_oclumon:
        node = ep_crudo.get("node")
        cat = ep_crudo.get("cat")
        inicio = datetime.fromisoformat(ep_crudo["start"])
        fin = datetime.fromisoformat(ep_crudo["end"])
        resumen = ep_crudo.get("narrativa") or ep_crudo.get("label", cat)
        interpretacion = ep_crudo.get("interpretacion", "")

        finding_type = resolver_finding_type(categoria=cat)
        definicion = CATALOGO[finding_type]

        evidencia_ids = _evidencia_para_episodio(eventos_hechos, node, inicio, fin)

        episodio_id = f"oclumon:{node}:{cat}:{ep_crudo.get('entity','')}:{inicio.isoformat()}"
        episodios_diag.append(EpisodioDiagnostico(
            id=episodio_id, finding_type=finding_type, nodo=node,
            inicio=inicio, fin=fin,
            severidad=ep_crudo.get("sev", "info"),
            resumen=resumen, interpretacion=interpretacion,
            hipotesis=[], limitaciones=[],
            evidencia_ids=evidencia_ids,
        ))

        activos, notas = _resolver_optional_panels(
            definicion, node, series_por_nodo, cobertura_por_fuente, node_list,
        )
        # panel_disparador: la metrica REAL que disparo ESTE episodio
        # puntual (resolver_panel_disparador(cat), no el finding_type
        # agrupado) -- solo se marca como tal si efectivamente quedo
        # activo (tiene cobertura real), nunca se destaca un panel que el
        # propio episodio no puede mostrar.
        disparador = resolver_panel_disparador(categoria=cat)
        if disparador not in activos:
            disparador = None
        componentes.append(ComponenteActivado(
            episodio_id=episodio_id, definicion=definicion,
            optional_panels_activos=activos, notas_cobertura=notas,
            panel_disparador=disparador,
        ))

    episodios_diag.sort(key=lambda e: (-{"critical": 2, "warning": 1, "info": 0}.get(e.severidad, 0),
                                        e.inicio))

    diagnostico = Diagnostico(
        episodios=episodios_diag,
        estado_global=estado_salud.get("estado", "OK") if estado_salud else "OK",
        motivos_estado_global=(estado_salud or {}).get("motivos", []),
    )

    # series_relevantes: antes venia de core/correlacion.py; ahora se
    # calcula directo contra series_por_nodo -- una serie es "relevante"
    # si al menos un nodo tiene al menos 1 punto real para ella.
    series_relevantes = {}
    for datos_nodo in series_por_nodo.values():
        for serie, puntos in datos_nodo.items():
            if _has_observed(puntos):
                series_relevantes[serie] = True
            else:
                series_relevantes.setdefault(serie, False)
    presentacion = Presentacion(componentes=componentes, series_relevantes=series_relevantes)

    informe = InformeCompleto(hechos=hechos, diagnostico=diagnostico, presentacion=presentacion)
    return informe.model_dump(mode="json")
