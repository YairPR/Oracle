#!/usr/bin/env python3
"""
export_icons.py

Script de UNA SOLA VEZ (no corre en produccion, no lo usa el usuario) para
vendorizar los iconos Lucide SVG necesarios desde node_modules/lucide-static
(instalado localmente solo para este paso) hacia core/icons.py -- un modulo
Python puro con las cadenas SVG ya embebidas como constantes.

Por que no se referencia node_modules/ en tiempo de ejecucion: node_modules
de dashboard-ui/ (con ECharts + esbuild + lucide-static completos) pesa
~110 MB y es un artefacto de BUILD, no algo que viaje a la maquina del
usuario -- igual que uPlot/Tabulator en el Hito 6 terminaban embebidos
inline en el HTML final en vez de requerir un CDN, estos iconos terminan
embebidos como constantes de texto en core/icons.py, que si viaja con
rac-lab/ como cualquier otro .py.

Licencia: Lucide se distribuye bajo ISC License (ver
node_modules/lucide-static/LICENSE) -- permite vendorizar/redistribuir los
SVG sin restriccion, con el aviso de copyright conservado (se deja la nota
en el docstring de core/icons.py generado).
"""
import re
from pathlib import Path

ICONS_DIR = Path(__file__).parent.parent / "node_modules" / "lucide-static" / "icons"
OUT_FILE = Path(__file__).parent.parent.parent / "core" / "icons.py"

# icon_id interno usado por el catalogo de componentes -> nombre de archivo lucide-static
ICON_MAP = {
    # Iconos base por casuistica (taxonomia pedida por el usuario)
    "node_down": "server",
    "instance_termination": "database",
    "dataguard": "database-zap",
    "ora_critical": "file-warning",
    "interconnect": "network",
    "asm_io": "hard-drive",
    "memory_pressure": "memory-stick",
    "cpu_saturation": "cpu",
    "job_sql_error": "file-code",
    "unknown_event": "file-question",
    # Distintivos de estado/severidad (se combinan con el icono base)
    "status_ok": "check-circle",
    "status_warning": "alert-triangle",
    "status_critical": "alert-octagon",
    "status_unconfirmed": "help-circle",
    "status_no_data": "slash",
    # Navegacion del sidebar
    "nav_resumen": "layout-dashboard",
    "nav_episodios": "list",
    "nav_timeline": "clock",
    "nav_red": "share-2",
    "nav_cpu_mem": "gauge",
    "nav_almacenamiento": "archive",
    "nav_evidencias": "table",
    "nav_calidad": "search",
    # Varios usados en paneles
    "trend": "activity",
    "correlacion": "git-compare",
    "transporte": "arrow-left-right",
    "repeticion": "repeat",
    "capas": "layers",
    "rayo": "zap",
    "rama": "git-branch",
}

_SVG_OPEN_RE = re.compile(r"<svg\b[^>]*>")


def normalizar_svg(svg_text: str) -> str:
    """Quita el ancho/alto fijos del SVG original (24x24) para que el CSS
    del dashboard controle el tamano via `width`/`height: 1em` + `currentColor`
    (asi el icono hereda el color de texto del contexto donde se use -- borde
    critico, badge de advertencia, item de sidebar activo, etc. -- sin tener
    que generar una variante de color por cada icono)."""
    svg_text = svg_text.strip()

    def _reescribir_apertura(m):
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" '
            'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
            'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">'
        )

    return _SVG_OPEN_RE.sub(_reescribir_apertura, svg_text, count=1)


def main():
    if not ICONS_DIR.is_dir():
        raise SystemExit(
            f"No se encontro {ICONS_DIR} -- correr 'npm install' en dashboard-ui/ primero."
        )

    entradas = []
    faltantes = []
    for icon_id, archivo in sorted(ICON_MAP.items()):
        ruta = ICONS_DIR / f"{archivo}.svg"
        if not ruta.is_file():
            faltantes.append((icon_id, archivo))
            continue
        svg = normalizar_svg(ruta.read_text(encoding="utf-8"))
        entradas.append((icon_id, archivo, svg))

    if faltantes:
        raise SystemExit(f"Iconos no encontrados en lucide-static: {faltantes}")

    lineas = [
        '"""',
        "core/icons.py",
        "",
        "Iconos SVG vendorizados de Lucide (https://lucide.dev, ISC License,",
        "Copyright (c) Lucide Contributors / isaacs) -- generado UNA VEZ por",
        "dashboard-ui/scripts/export_icons.py, no se regenera en cada corrida.",
        "Cada icono se normaliza a 1em x 1em con stroke=currentColor, para que",
        "herede el color de texto de donde se use (badge critico, item activo",
        "del sidebar, etc.) sin necesitar una variante por color.",
        "",
        "ICONOS = {icon_id: '<svg ...>...</svg>'} -- ver core/component_catalog.py",
        "para el mapeo de cada casuistica a su icon_id, y templates/ para donde",
        "se renderizan (Jinja2 los marca |safe porque el SVG sale de ESTE modulo,",
        "nunca de un dato de usuario -- ningun otro |safe se usa en el proyecto).",
        '"""',
        "",
        "ICONOS = {",
    ]
    for icon_id, archivo, svg in entradas:
        svg_escapado = svg.replace("\\", "\\\\").replace('"""', '\\"\\"\\"')
        lineas.append(f'    "{icon_id}": """{svg_escapado}""",  # lucide: {archivo}')
    lineas.append("}")
    lineas.append("")

    OUT_FILE.write_text("\n".join(lineas), encoding="utf-8")
    print(f"Escritos {len(entradas)} iconos en {OUT_FILE}")


if __name__ == "__main__":
    main()
