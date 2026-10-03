/**
 * colors.ts -- "colores estables por nodo en todas las vistas", pedido
 * explicito del usuario. Un nodo se asigna a un color por su POSICION en
 * node_list (que ya viene ordenado alfabeticamente desde
 * core/episode_engine.py -- build_dataset() hace sorted(nodes.keys()) al
 * armar node_list), asi que el mismo nodo siempre cae en el mismo color
 * entre una corrida y otra del mismo caso, sin necesidad de guardar un
 * mapeo en ningun lado.
 *
 * Rediseno 2026-10-02 (tema oscuro premium): estos hex son el espejo
 * EXACTO de las variables --color-node-N / --color-critical / --color-warning
 * / --color-ok de templates/static/theme.css -- 6 de los 8 tonos
 * categoricos validados por la skill `dataviz` para la superficie oscura
 * #1a1a19 (orden fijo, nunca ciclado mas alla de los 6 nodos reales que
 * un RAC de este tamano puede tener), mas los 4 pasos de la paleta de
 * estado FIJA (nunca tematizada). Validado con
 * `node scripts/validate_palette.js "<hex,...>" --mode dark` -- todos los
 * checks PASS (contraste >=3:1 contra la superficie, separacion CVD y de
 * vision normal por encima del piso).
 */

const PALETA_NODO = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#9085e9"];

let ordenNodos: string[] = [];

export function registrarNodos(nodeList: string[]): void {
  ordenNodos = [...nodeList];
}

export function colorDeNodo(nodo: string | null | undefined): string {
  if (!nodo) return "#898781";
  const idx = ordenNodos.indexOf(nodo);
  if (idx === -1) return "#898781";
  return PALETA_NODO[idx % PALETA_NODO.length];
}

export const COLOR_CRITICAL = "#d03b3b";
export const COLOR_WARNING = "#fab219";
export const COLOR_OK = "#0ca30c";
export const COLOR_NODATA = "#898781";
export const COLOR_ACCENT = "#3987e5";

export function colorDeSeveridad(sev: string | undefined): string {
  if (sev === "critical") return COLOR_CRITICAL;
  if (sev === "warning") return COLOR_WARNING;
  if (sev === "info") return COLOR_ACCENT;
  return COLOR_OK;
}
