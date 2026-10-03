/**
 * main.ts -- punto de entrada del bundle. Lee window.__PAYLOAD__ (el JSON
 * que analizador.py embebe en el HTML final, ver generar_reporte_html())
 * y monta: la cronologia correlacionada, cada chart declarado via
 * [data-chart] en el HTML server-renderizado (Jinja2 decide CUALES
 * paneles existen -- ver core/dashboard_engine.py -- este bundle solo
 * sabe DIBUJAR lo que ya se decidio mostrar), la navegacion del sidebar y
 * los filtros.
 */

import { registrarNodos } from "./colors";
import {
  renderSerieChart, renderSerieMultiNodo, renderCronologia, renderSerieCruda,
  renderSerieCrudaMulti, renderBarraApiladaDbTime, reflowCharts, conectarCharts,
} from "./charts";
import { inicializarNav } from "./nav";
import { inicializarSelectorPanel, inicializarExpandirEvidencia, inicializarFiltrosTimeline } from "./filters";
import type { Payload } from "./types";

interface ChartSpec {
  kind: "serie" | "multi-nodo" | "cronologia" | "serie-cruda" | "serie-cruda-multi" | "barra-apilada-dbtime";
  node?: string;
  nodos?: string[];
  series?: string[];
  nombres?: string[];
  area?: boolean;
  serie?: string;
  title?: string;
  unit?: string;
  fuente?: "series_cpu" | "series_aas";
  fuentes?: string[];
  clave?: string;
}

function montarCharts(payload: Payload): void {
  const nodos = document.querySelectorAll<HTMLElement>("[data-chart]");
  nodos.forEach((el) => {
    const raw = el.getAttribute("data-chart");
    if (!raw) return;
    let spec: ChartSpec;
    try {
      spec = JSON.parse(raw);
    } catch {
      el.innerHTML = '<div class="odl-empty-state">Especificacion de grafico invalida.</div>';
      return;
    }
    if (spec.kind === "cronologia") {
      renderCronologia(el, payload);
    } else if (spec.kind === "multi-nodo" && spec.serie) {
      renderSerieMultiNodo(el, payload, {
        serie: spec.serie, nodos: spec.nodos || payload.motor_episodios.node_list,
        title: spec.title, unit: spec.unit,
      });
    } else if (spec.kind === "serie" && spec.node && spec.series) {
      renderSerieChart(el, payload, {
        node: spec.node, series: spec.series, nombres: spec.nombres,
        area: spec.area, title: spec.title, unit: spec.unit,
      });
    } else if (spec.kind === "serie-cruda" && spec.fuente) {
      renderSerieCruda(el, payload, { fuente: spec.fuente, clave: spec.clave, title: spec.title, unit: spec.unit });
    } else if (spec.kind === "serie-cruda-multi" && spec.fuentes) {
      renderSerieCrudaMulti(el, payload, { fuentes: spec.fuentes, nombres: spec.nombres, title: spec.title, unit: spec.unit });
    } else if (spec.kind === "barra-apilada-dbtime") {
      renderBarraApiladaDbTime(el, payload);
    }
  });
}

function main(): void {
  const payload = window.__PAYLOAD__;
  if (!payload) {
    // eslint-disable-next-line no-console
    console.error("RAC Forensic Lab: window.__PAYLOAD__ no esta presente -- el informe no se puede renderizar.");
    return;
  }
  registrarNodos(payload.motor_episodios.node_list || []);
  montarCharts(payload);
  // Linea de tiempo maestra (echarts.connect) -- DESPUES de montar todos
  // los charts, nunca antes (ver conectarCharts() en charts.ts).
  conectarCharts();
  inicializarNav();
  // Selectores de la seccion OCLUMON (rediseno "meramente grafico",
  // 2026-10-02) -- cada uno controla su propio grupo de paneles
  // (data-panel-group), ver templates/dashboard.html::sec-oclumon.
  inicializarSelectorPanel("odl-selector-device", "device");
  inicializarSelectorPanel("odl-selector-fs", "fs");
  inicializarSelectorPanel("odl-selector-proc-nodo", "proc-nodo");
  inicializarExpandirEvidencia();
  inicializarFiltrosTimeline();
  window.addEventListener("resize", () => window.setTimeout(reflowCharts, 80));
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", main);
} else {
  main();
}
