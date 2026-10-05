"""
core/html_builder.py

Ensamblado del informe HTML final con Jinja2 real (Hito "Oracle Diagnostic
Lab", 2026-10-01) -- reemplaza el `html.replace("__PAYLOAD_JSON__", ...)`
de texto plano que usaba `generar_reporte_html()` en analizador.py desde
el Hito 6. Con Jinja2 real: autoescape activado (ningun mensaje de log se
inserta sin escapar en el HTML -- pedido explicito del usuario, "Activaria
el escape de HTML al representar mensajes de los logs"), plantillas
componibles (`templates/base.html` + `templates/macros.html`, en vez de un
unico archivo de 600+ lineas), y el JSON del payload + el CSS + el bundle
JS se siguen embebiendo INLINE -- el informe sigue siendo un unico .html
offline, el cambio es como se arma, no que se arma.

`render_dashboard()` es la unica funcion publica -- analizador.py la
llama con el mismo payload que ya arma construir_payload() (mas
`iconos`, que sale de core/icons.py, vendorizado una sola vez).
"""

import json
import os
from datetime import datetime, timedelta, timezone

from jinja2 import Environment, FileSystemLoader, select_autoescape

from core.icons import ICONOS

_TEMPLATES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "templates")
_STATIC_DIR = os.path.join(_TEMPLATES_DIR, "static")

_SEV_RANK = {"critical": 2, "warning": 1, "info": 0}

# Color por Wait Class de AWR (seccion AWR, Hito "rediseno AWR" 2026-10-02):
# reutiliza los mismos 6 tonos de nodo ya validados con la skill `dataviz`
# (ver claude/rac_forensic_lab.md, hito "Tema oscuro premium") -- aca NO
# representan un nodo, son solo 6 tonos distintos y ya verificados para
# diferenciar categorias en la superficie oscura. Nunca se suma un color
# nuevo sin pasar por scripts/validate_palette.js (ver Pendiente del
# proyecto, "Reconciliacion de paleta"). "Cluster" (Global Cache / RAC
# interconnect waits -- gc cr block busy, gc buffer busy, etc.) tiene su
# propio tono fijo a proposito, es la categoria mas relevante para RAC.
_WAIT_CLASS_COLOR = {
    "Cluster": "var(--color-node-1)",
    "User I/O": "var(--color-node-0)",
    "System I/O": "var(--color-node-2)",
    "Concurrency": "var(--color-node-4)",
    "Application": "var(--color-node-3)",
    "Commit": "var(--color-node-5)",
    "Configuration": "var(--color-node-2)",
    "Network": "var(--color-node-0)",
    "Scheduler": "var(--color-node-3)",
    "Administrative": "var(--color-node-4)",
    "Other": "var(--color-text-faint)",
    "Idle": "var(--color-text-faint)",
}


def _color_wait_class(wait_class):
    """Filtro Jinja2 -- color CSS para un badge de Wait Class de AWR.
    Nunca lanza: una clase no mapeada (version de Oracle con un nombre
    distinto) cae al tono neutro en vez de romper el render."""
    return _WAIT_CLASS_COLOR.get(wait_class, "var(--color-text-faint)")


def _filtro_hora(valor_iso):
    """'2026-09-30T02:45:08' -> '02:45:08'. Nunca lanza -- un valor no
    parseable se devuelve tal cual, mejor mostrar el dato crudo que
    reventar el render de todo el informe por un timestamp raro."""
    if not valor_iso:
        return "--:--:--"
    try:
        return datetime.fromisoformat(valor_iso).strftime("%H:%M:%S")
    except (ValueError, TypeError):
        return str(valor_iso)


def _filtro_fecha_hora(valor_iso):
    if not valor_iso:
        return "sin dato"
    try:
        return datetime.fromisoformat(valor_iso).strftime("%d %b %Y, %H:%M:%S")
    except (ValueError, TypeError):
        return str(valor_iso)


def _filtro_duracion(segundos):
    """123 -> '2m 3s'. Nunca lanza."""
    try:
        s = int(segundos)
    except (ValueError, TypeError):
        return "--"
    if s < 60:
        return f"{s}s"
    m, s = divmod(s, 60)
    if m < 60:
        return f"{m}m {s}s"
    h, m = divmod(m, 60)
    return f"{h}h {m}m"


def _crear_entorno() -> Environment:
    env = Environment(
        loader=FileSystemLoader(_TEMPLATES_DIR),
        autoescape=select_autoescape(["html"]),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    env.filters["hora"] = _filtro_hora
    env.filters["fecha_hora"] = _filtro_fecha_hora
    env.filters["duracion"] = _filtro_duracion
    env.filters["color_wait_class"] = _color_wait_class
    return env


def calcular_kpis(payload: dict) -> dict:
    """Deriva los 4 KPI de la ficha tecnica de cabecera (Impacto / Causa
    raiz / Episodios / Cobertura OCLUMON, tal como los pidio el usuario en
    su maqueta) a partir de 'informe' (ver core/dashboard_engine.py) y
    'motor_episodios'. Es presentacion pura -- no forma parte del
    contrato Hechos/Diagnostico/Presentacion, por eso vive aca y no en
    dashboard_engine.py. Nunca lanza: cualquier dato faltante cae en un
    KPI neutro ('sin datos') en vez de romper el render."""
    informe = payload.get("informe") or {}
    diagnostico = informe.get("diagnostico") or {}
    episodios = diagnostico.get("episodios") or []
    motor_ep = payload.get("motor_episodios") or {}

    estado = diagnostico.get("estado_global", "OK")
    sev_map = {"CRITICAL": "critical", "WARNING": "warning", "OK": "ok"}
    # Texto en espanol para la ficha tecnica -- 'estado_global'/'CRITICAL' etc.
    # en ingles se mantiene como VALOR INTERNO (lo usa ai.engine.calcular_
    # estado_salud() desde antes, no se renombra para no romper esa capa),
    # pero la etiqueta visible en el KPI es la que pidio el usuario en su
    # maqueta ("CRÍTICO", no "CRITICAL").
    etiqueta_estado = {"CRITICAL": "CRÍTICO", "WARNING": "ADVERTENCIA", "OK": "OK"}
    top_episodio = episodios[0] if episodios else None
    impacto = {
        "valor": etiqueta_estado.get(estado, estado),
        "sev": sev_map.get(estado, "ok"),
        "sub": (top_episodio.get("resumen") if top_episodio else "Sin hallazgos en este caso"),
    }

    confirmadas = [h for e in episodios for h in e.get("hipotesis", []) if h.get("estado") == "confirmada"]
    en_estudio = [h for e in episodios for h in e.get("hipotesis", []) if h.get("estado") == "en_estudio"]
    if confirmadas:
        causa_raiz = {"valor": "CONFIRMADA", "sub": confirmadas[0]["titulo"]}
    elif en_estudio:
        causa_raiz = {"valor": "EN ESTUDIO", "sub": en_estudio[0]["titulo"]}
    else:
        causa_raiz = {
            "valor": "NO CONFIRMADA",
            "sub": (top_episodio.get("resumen", "") if top_episodio else "Investigar manualmente"),
        }

    if episodios:
        horas = sorted({_filtro_hora(e.get("inicio")) for e in episodios})
        episodios_kpi = {
            "valor": str(len(episodios)),
            "sub": ", ".join(horas[:3]) + (f" (+{len(horas) - 3})" if len(horas) > 3 else ""),
        }
    else:
        episodios_kpi = {"valor": "0", "sub": "Sin episodios detectados"}

    node_list = motor_ep.get("node_list") or []
    diags = motor_ep.get("oclumon_diagnostics") or []
    primeros = [d["first_clock"] for d in diags if d.get("first_clock")]
    ultimos = [d["last_clock"] for d in diags if d.get("last_clock")]
    if node_list and primeros and ultimos:
        cobertura = {
            "valor": f"{len(node_list)} nodo(s)",
            "sub": f"{_filtro_hora(min(primeros))} - {_filtro_hora(max(ultimos))}",
        }
    elif node_list:
        cobertura = {"valor": f"{len(node_list)} nodo(s)", "sub": "Rango de tiempo no disponible"}
    else:
        cobertura = {"valor": "SIN DATOS", "sub": "Sin archivos OCLUMON en este caso"}

    return {"impacto": impacto, "causa_raiz": causa_raiz, "episodios": episodios_kpi, "cobertura": cobertura}


# Como traducir cada panel OPCIONAL del catalogo (core/component_catalog.py)
# a una especificacion de grafico que dashboard-ui/src/main.ts sabe
# dibujar (ver ChartSpec en types.ts). Paneles que no aparecen aca no son
# un grafico -- se resuelven con markup directo en templates/dashboard.html
# (tablas de evidencia, secuencias de eventos, detalle de error).
#
# nic_discards_chart/nic_link_errors_chart/protocol_ip_reasfail_chart/
# protocol_udp_rcverr_chart (rediseno 2026-10-02): antes el catalogo tenia
# un unico 'protocol_errors_chart' generico sin spec (las contadoras vivian
# solo en eventos_forenses crudo) -- desde que core/episode_engine.py
# expone ip_reasfail/udp_rcverr/descartes/errores-de-NIC como series reales
# en series_por_nodo, cada categoria de episodio de interconnect grafica su
# propia metrica real (ver resolver_panel_disparador() en
# core/component_catalog.py, que decide cual de estos 6 paneles es la causa
# real de CADA episodio puntual).
_PANEL_A_CHART_SPEC = {
    "cpu_by_node": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["cpu_pct"], "title": "CPU", "unit": "%"},
    "cpu_by_node_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["cpu_pct"], "title": "CPU", "unit": "%"},
    "cpu_queue_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["cpuq"], "title": "Cola de CPU", "unit": "procesos en cola"},
    "memory_pressure_panel": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["memfree_mb", "swapfree_mb"], "title": "Memoria y swap libres", "unit": "MB"},
    "memory_by_node_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["memfree_mb"], "title": "Memoria libre", "unit": "MB"},
    "swap_by_node_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["swapfree_mb"], "title": "Swap libre", "unit": "MB"},
    "interconnect_errors": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["interconnect_latency_ms"], "title": "Latencia interconnect", "unit": "ms"},
    "interconnect_latency_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["interconnect_latency_ms"], "title": "Latencia interconnect", "unit": "ms"},
    "interconnect_traffic_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["interconnect_kbps"], "title": "Tráfico interconnect", "unit": "KB/s"},
    "nic_discards_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["interconnect_nic_discards"], "title": "Descartes en NIC PRIVATE según la fuente", "unit": "paquetes/s"},
    "nic_link_errors_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["interconnect_nic_link_errors"], "title": "Errores de capa NIC (errsin+errsout)", "unit": "errores/muestra"},
    "protocol_ip_reasfail_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["ip_reasfail"], "title": "Fallos de reensamblado IP (IPReasFail)", "unit": "fallos nuevos/muestra"},
    "protocol_udp_rcverr_chart": lambda ep: {"kind": "serie", "node": ep["nodo"], "series": ["udp_rcverr"], "title": "Errores de recepción UDP (UDPRcvErr)", "unit": "errores nuevos/muestra"},
    "resources_by_node": lambda ep: {"kind": "multi-nodo", "serie": "cpu_pct", "title": "CPU comparada entre nodos", "unit": "%"},
}


def adjuntar_evidencia_resuelta(informe: dict) -> None:
    """Resuelve evidencia_ids (indices sobre informe.hechos.eventos) a los
    eventos reales, IN PLACE, bajo una clave nueva 'evidencia_resuelta' en
    cada episodio -- se hace aca en Python (una sola vez, O(1) por indice)
    en vez de en la plantilla Jinja2, porque Jinja2 no tiene una forma
    limpia de indexar una lista con una lista de indices sin recurrir a
    filtros encadenados fragiles. No forma parte del contrato Pydantic
    (InformeCompleto) a proposito -- es un enriquecimiento de presentacion
    que solo le importa al template, calculado despues de la validacion."""
    eventos = informe.get("hechos", {}).get("eventos", [])
    for ep in informe.get("diagnostico", {}).get("episodios", []):
        ep["evidencia_resuelta"] = [
            eventos[i] for i in ep.get("evidencia_ids", []) if 0 <= i < len(eventos)
        ]


def construir_chart_specs(informe: dict) -> dict:
    """{episodio_id: {panel_name: spec_dict | None}} -- se calcula UNA vez
    por render (no en cada macro de Jinja2) para mantener la plantilla
    simple y para que un panel sin spec (ver _PANEL_A_CHART_SPEC) quede
    explicitamente en None y el template pueda decidir el fallback
    (puntero a la tabla cruda) en un solo lugar."""
    out = {}
    for comp in (informe.get("presentacion") or {}).get("componentes", []):
        episodio = next(
            (e for e in informe["diagnostico"]["episodios"] if e["id"] == comp["episodio_id"]), None,
        )
        if episodio is None:
            continue
        specs = {}
        for panel in comp["optional_panels_activos"]:
            builder = _PANEL_A_CHART_SPEC.get(panel)
            specs[panel] = builder(episodio) if builder else None
        out[comp["episodio_id"]] = specs
    return out


def compactar_payload_wire(payload):
    """Shared clocks and constants, lossless; templates still see original arrays."""
    wire = dict(payload)
    motor = dict(payload["motor_episodios"])
    # Older states from this iteration stored one metadata label per sample.
    # Preserve changes and gaps while compacting these labels for presentation.
    inventory = {}
    for node, interfaces in motor.get("nic_inventory", {}).items():
        inventory[node] = {}
        step = (motor.get("coverage", {}).get(node, {}).get("cadence_seconds") or 1)
        for name, records in interfaces.items():
            runs = []
            for record in records:
                if "t" not in record:
                    runs.append(dict(record))
                    continue
                previous = runs[-1] if runs else None
                if previous and previous["type"] == record["type"] and previous["mtu"] == record.get("mtu") and 0 < record["t"] - previous["to"] <= step * 1.5:
                    previous["to"] = record["t"]
                else:
                    runs.append({"from": record["t"], "to": record["t"], "type": record["type"], "mtu": record.get("mtu")})
            inventory[node][name] = runs
    motor["nic_inventory"] = inventory
    clocks = dict(motor.get("series_timestamps", {}))
    clock_ids = {tuple(times): clock for clock, times in clocks.items()}
    series = {}
    sample_times = set(motor.get("timestamps_muestras", []))
    for node, metrics in motor.get("series_por_nodo", {}).items():
        series[node] = {}
        for name, points in metrics.items():
            if not points or isinstance(points, dict) and "clock" in points:
                series[node][name] = points
                continue
            times = tuple(p[0] if isinstance(p, list) else p["t"] for p in points)
            values = [p[1] if isinstance(p, list) else p.get("v") for p in points]
            flags = [i for i,p in enumerate(points) if (isinstance(p, list) and len(p)>2 and p[2]) or (isinstance(p, dict) and p.get("lt"))]
            for t,v in zip(times,values):
                if v is not None:
                    sample_times.add(t)
            clock = clock_ids.get(times)
            if clock is None:
                clock = str(len(clocks))
                clock_ids[times] = clock
                clocks[clock] = list(times)
            nonnull = {v for v in values if v is not None}
            encoded = {"clock": clock}
            if len(nonnull) == 1:
                encoded["constant"] = next(iter(nonnull))
                nulls = [i for i,v in enumerate(values) if v is None]
                if nulls: encoded["nulls"] = nulls
            else:
                encoded["values"] = values
            if flags: encoded["lt"] = flags
            series[node][name] = encoded
    motor["series_por_nodo"] = series
    motor["series_timestamps"] = clocks
    motor["timestamps_muestras"] = sorted(sample_times)
    wire["motor_episodios"] = motor
    return wire


def display_clock(payload: dict) -> dict:
    """Present a single documented capture offset; keep stored instants unchanged."""
    motor = payload.get("motor_episodios") or {}
    domains = motor.get("time_domains") or ["unknown"]
    if len(domains) == 1 and domains[0] != "unknown" and not payload.get("infraestructura") and not motor.get("nodos_sar"):
        domain = domains[0].replace(":", "")
        if len(domain) == 5 and domain[0] in "+-" and domain[1:].isdigit():
            minutes = (int(domain[1:3]) * 60 + int(domain[3:5])) * (-1 if domain[0] == "-" else 1)
            if abs(minutes) < 1440 and int(domain[3:5]) < 60:
                return {"offset_minutes": minutes, "label": f"UTC{domain[:3]}:{domain[3:]} · hora de captura"}
    return {"offset_minutes": 0, "label": "Hora de captura · zona no declarada" if domains == ["unknown"] else "UTC · referencia común entre fuentes"}


def _capture_date(value, offset, pattern):
    try:
        dt = datetime.fromisoformat(value)
        if dt.tzinfo is not None:
            dt = dt.astimezone(timezone(timedelta(minutes=offset)))
        else:
            dt += timedelta(minutes=offset)
        return dt.strftime(pattern)
    except (ValueError, TypeError):
        return str(value) if value else "sin dato"


def render_dashboard(payload: dict) -> str:
    """Arma el HTML final: lee templates/base.html + templates/dashboard.html
    via Jinja2 (autoescape activado), con el CSS de templates/static/theme.css
    y el bundle JS de templates/static/dashboard.bundle.js inlineados, mas
    el payload completo como JSON embebido para que dashboard-ui/src/main.ts
    lo lea en window.__PAYLOAD__. Nunca asume que esos 2 archivos estaticos
    existen sin chequear -- un error claro ('correr npm run build primero')
    es mejor que un KeyError críptico en medio del render."""
    for nombre in ("theme.css", "dashboard.bundle.js"):
        ruta = os.path.join(_STATIC_DIR, nombre)
        if not os.path.isfile(ruta):
            raise FileNotFoundError(
                f"Falta {ruta} -- correr 'npm run build' dentro de dashboard-ui/ antes de "
                "generar el informe (ver dashboard-ui/README.md)."
            )

    with open(os.path.join(_STATIC_DIR, "theme.css"), encoding="utf-8") as f:
        css_inline = f.read()
    with open(os.path.join(_STATIC_DIR, "dashboard.bundle.js"), encoding="utf-8") as f:
        js_inline = f.read()
    # Mismo escape que ya aplicaba el Hito 6 -- un '</script>' literal
    # dentro de un 'detalles' (texto libre de un log real) no debe poder
    # cortar el bloque <script> del JSON embebido a mitad de camino.
    js_inline = js_inline.replace("</script", "<\\/script")

    payload = {**payload, "display_clock": display_clock(payload)}
    payload_json = json.dumps(compactar_payload_wire(payload), ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")

    env = _crear_entorno()
    offset = payload["display_clock"]["offset_minutes"]
    env.filters["fecha_captura"] = lambda value: _capture_date(value, offset, "%d %b %Y, %H:%M:%S")
    env.filters["hora_captura"] = lambda value: _capture_date(value, offset, "%H:%M:%S")
    template = env.get_template("dashboard.html")
    informe = payload.get("informe") or {
        "diagnostico": {"episodios": [], "estado_global": "OK", "motivos_estado_global": []},
        "presentacion": {"componentes": [], "series_relevantes": {}},
        "hechos": {"eventos": [], "entidades": []},
    }
    adjuntar_evidencia_resuelta(informe)
    return template.render(
        payload=payload,
        kpis=calcular_kpis(payload),
        iconos=ICONOS,
        css_inline=css_inline,
        js_inline=js_inline,
        payload_json=payload_json,
        chart_specs=construir_chart_specs(informe),
    )
