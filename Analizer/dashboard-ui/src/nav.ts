/**
 * nav.ts -- barra de pestañas superior (rediseno "rediseno AWR + tabs +
 * LogRouter acotado", 2026-10-02, pedido explicito del usuario:
 * "rediseña el dasboard en pestañas ya no el panel izquierdo").
 *
 * Reemplaza la version anterior (click-to-scroll + IntersectionObserver
 * sobre un sidebar fijo, documento de una sola pagina larga) por
 * mostrar/ocultar real: un solo <section data-tab-panel> visible a la
 * vez. Mismo patron ya validado en este proyecto por
 * filters.ts::inicializarSelectorPanel() -- togglear una CLASE
 * (".odl-tab-activo"/".active"), nunca `style.display` a mano (eso lo
 * decide el CSS de theme.css: "[data-tab-panel] { display:none }" /
 * ".odl-tab-activo { display:block }"), y un reflowCharts() diferido
 * despues de cada cambio porque ECharts no redibuja bien un canvas que
 * estuvo oculto con display:none.
 */

import { reflowCharts } from "./charts";

export function inicializarNav(): void {
  const items = Array.from(document.querySelectorAll<HTMLElement>(".odl-tab-item[data-target]"));
  if (!items.length) return;

  const paneles = items
    .map((i) => document.getElementById(i.getAttribute("data-target") || ""))
    .filter((el): el is HTMLElement => !!el);
  if (!paneles.length) return;

  const activar = (id: string) => {
    for (const item of items) {
      item.classList.toggle("active", item.getAttribute("data-target") === id);
    }
    for (const panel of paneles) {
      panel.classList.toggle("odl-tab-activo", panel.id === id);
    }
    // Los charts del panel que acaba de volverse visible se montaron con
    // echarts.init() mientras estaban en display:none (Jinja2 ya los
    // renderiza todos de entrada) -- sin este resize diferido quedan con
    // tamano 0x0 hasta el proximo resize de ventana.
    window.setTimeout(reflowCharts, 60);
  };

  for (const item of items) {
    item.addEventListener("click", () => {
      const id = item.getAttribute("data-target");
      if (id) activar(id);
    });
  }
}
