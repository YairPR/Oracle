/**
 * filters.ts -- filtros de UI que no requieren volver a pedir nada al
 * servidor (el informe es offline, todo el dato ya esta embebido):
 *
 *   - inicializarSelectorPanel(): un <select> generico que muestra/oculta
 *     paneles ya renderizados por Jinja2 segun su data-panel-key -- usado
 *     por la seccion OCLUMON (rediseno "meramente grafico", 2026-10-02)
 *     para los paneles de Dispositivos/Filesystems/Procesos, donde el
 *     nombre real (device, punto de montaje, nodo) varia por caso y no
 *     tiene sentido mostrar los 10+ a la vez.
 *   - inicializarExpandirEvidencia(): el boton "mostrar/ocultar" de la
 *     tabla cruda en la seccion de Evidencias.
 *   - inicializarFiltrosTimeline(): filtros rapidos (severidad/nodo/
 *     texto) sobre las filas ya renderizadas de la linea de tiempo
 *     consolidada (sec-timeline) -- pedido del audit externo pegado por
 *     el usuario el 2026-10-02 ("agregarle filtros rapidos interactivos").
 *     Puramente client-side: oculta/muestra <tr> ya presentes en el DOM,
 *     nunca vuelve a pedir nada al servidor (el informe es offline).
 *
 * ECharts no redibuja bien un canvas que estuvo con display:none, asi
 * que cada toggle re-dispara un resize de los charts que quedaron
 * visibles (reflowCharts).
 */

import { reflowCharts } from "./charts";

/** selectorId: id del <select>. grupo: valor de data-panel-group que
 * agrupa los paneles que ese selector controla -- permite tener varios
 * selectores independientes en la misma pagina (Dispositivos,
 * Filesystems, Procesos) sin que se interfieran entre si. */
export function inicializarSelectorPanel(selectorId: string, grupo: string): void {
  const selector = document.getElementById(selectorId) as HTMLSelectElement | null;
  if (!selector) return;

  const aplicar = (valor: string) => {
    const paneles = document.querySelectorAll<HTMLElement>(`[data-panel-group="${grupo}"]`);
    for (const p of paneles) {
      const clave = p.getAttribute("data-panel-key");
      p.classList.toggle("odl-panel-activo", clave === valor);
    }
    window.setTimeout(reflowCharts, 60);
    document.dispatchEvent(new CustomEvent("odl:panel-visible"));
  };

  selector.addEventListener("change", () => aplicar(selector.value));
  // Estado inicial: el servidor ya deja seleccionada la primera opcion en
  // el HTML (ver templates/dashboard.html), pero los paneles arrancan
  // todos ocultos (ver theme.css, [data-panel-group]) -- se activa el que
  // corresponde a la opcion actual al montar, sin esperar un change real.
  if (selector.value) aplicar(selector.value);
}

export function inicializarExpandirEvidencia(): void {
  document.querySelectorAll<HTMLElement>("[data-toggle-evidencia]").forEach((boton) => {
    boton.addEventListener("click", () => {
      const id = boton.getAttribute("data-toggle-evidencia");
      if (!id) return;
      const bloque = document.getElementById(id);
      if (!bloque) return;
      const oculto = bloque.style.display === "none";
      // "" en vez de "block" a proposito: deja que la hoja de estilos
      // decida el display real (block para un div normal como
      // "tabla-cruda", grid para un "panel-grid" como "protocolo-otros")
      // en vez de pisarlo siempre con block, lo que rompia el layout de
      // 2 columnas de un panel-grid oculto por este mismo mecanismo.
      bloque.style.display = oculto ? "" : "none";
      boton.setAttribute("aria-expanded", String(oculto));
      // Un bloque revelado puede traer chart-box (p.ej. "protocolo-otros")
      // inicializados en display:none -- mismo caso que
      // inicializarSelectorPanel(), necesitan un resize despues de
      // volverse visibles.
      window.setTimeout(reflowCharts, 60);
    });
  });
}

/** Filtros rapidos de la linea de tiempo consolidada (sec-timeline):
 * severidad (data-timeline-sev, botones "Todos"/"Solo críticos"), nodo
 * (data-timeline-node, un boton por nodo + "Todos") y texto libre
 * (#odl-timeline-buscar). Los 3 criterios se combinan con AND sobre las
 * filas ya renderizadas (data-sev/data-node en cada <tr>) -- nunca se
 * vuelve a pedir nada al servidor. */
export function inicializarFiltrosTimeline(): void {
  const seccion = document.getElementById("sec-timeline");
  if (!seccion) return;
  const filas = Array.from(seccion.querySelectorAll<HTMLTableRowElement>("tbody tr[data-sev]"));
  if (!filas.length) return;

  const estado = { sev: "all", node: "all", texto: "" };

  const aplicar = (): void => {
    for (const fila of filas) {
      const sevOk = estado.sev === "all" || fila.getAttribute("data-sev") === estado.sev;
      const nodeOk = estado.node === "all" || fila.getAttribute("data-node") === estado.node;
      const textoOk = !estado.texto || (fila.textContent || "").toLowerCase().includes(estado.texto);
      fila.dataset.localHidden=String(!(sevOk && nodeOk && textoOk));
      fila.hidden=fila.dataset.localHidden==='true' || fila.dataset.rangeHidden==='true';
    }
  };

  seccion.querySelectorAll<HTMLElement>("[data-timeline-sev]").forEach((boton) => {
    boton.addEventListener("click", () => {
      estado.sev = boton.getAttribute("data-timeline-sev") || "all";
      seccion.querySelectorAll("[data-timeline-sev]").forEach((b) => b.classList.remove("odl-filter-activo"));
      boton.classList.add("odl-filter-activo");
      aplicar();
    });
  });
  seccion.querySelectorAll<HTMLElement>("[data-timeline-node]").forEach((boton) => {
    boton.addEventListener("click", () => {
      estado.node = boton.getAttribute("data-timeline-node") || "all";
      seccion.querySelectorAll("[data-timeline-node]").forEach((b) => b.classList.remove("odl-filter-activo"));
      boton.classList.add("odl-filter-activo");
      aplicar();
    });
  });
  const buscar = document.getElementById("odl-timeline-buscar") as HTMLInputElement | null;
  if (buscar) {
    buscar.addEventListener("input", () => {
      estado.texto = buscar.value.trim().toLowerCase();
      aplicar();
    });
  }
}
