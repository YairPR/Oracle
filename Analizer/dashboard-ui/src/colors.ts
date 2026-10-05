/** Stable report-wide host colors. Additional hosts use distinct hues and line styles. */

const PALETA_NODO = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#9085e9"];

let ordenNodos: string[] = [];

export function registrarNodos(nodeList: string[]): void {
  ordenNodos = [...nodeList];
}

export function colorDeNodo(nodo: string | null | undefined): string {
  if (!nodo) return "#898781";
  const idx = ordenNodos.indexOf(nodo);
  if (idx === -1) return "#898781";
  if (idx < PALETA_NODO.length) return PALETA_NODO[idx];
  // Additional hosts receive distinct colors rather than cycling six colors.
  return `hsl(${(idx * 137.508) % 360} 65% ${58 + (idx % 3)*5}%)`;
}

export const COLOR_CRITICAL = "#d03b3b";
export function lineTypeDeNodo(nodo: string): 'solid' | 'dashed' | 'dotted' {
  const idx=ordenNodos.indexOf(nodo);
  return idx<6?'solid':(['solid','dashed','dotted'] as const)[idx%3];
}
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
