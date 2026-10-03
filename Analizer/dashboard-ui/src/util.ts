/**
 * util.ts -- utilidades chicas compartidas.
 */

const MAPA_ESCAPE: Record<string, string> = {
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
};

/** Escapa texto antes de insertarlo como HTML -- necesario en los
 * formatters de tooltip de ECharts (se renderizan como HTML real), ya
 * que el texto puede venir de una linea de log real sin ninguna garantia
 * de que no contenga '<'/'>' literales (Jinja2 ya escapa el HTML server-
 * side para el resto del documento, pero los tooltips de ECharts se arman
 * en el cliente a partir del JSON embebido, asi que necesitan su propio
 * escape aca). */
export function escapeHtml(texto: string): string {
  return String(texto).replace(/[&<>"']/g, (c) => MAPA_ESCAPE[c]);
}
